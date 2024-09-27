//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ERC721ACQueryableInitializable, ERC721AUpgradeable, IERC721AUpgradeable} from "../../creator-token-standards/ERC721ACQueryableInitializable.sol";
import {MINT_FEE_RECEIVER} from "../../../utils/Constants.sol";
import {UpdatableRoyaltiesInitializable, ERC2981} from "../../../royalties/UpdatableRoyaltiesInitializable.sol";
import {MintStageInfo} from "../../../common/Structs.sol";
import {IERC721MInitializable} from "../interfaces/IERC721MInitializable.sol";
/**
 * @title ERC721CMInitializableV2
 * @dev This contract is not meant for use in Upgradeable Proxy contracts though it may base on Upgradeable contract. The purpose of this
 * contract is for use with EIP-1167 Minimal Proxies (Clones).
 */
contract ERC721CMInitializableV2 is
    IERC721MInitializable,
    ERC721ACQueryableInitializable,
    UpdatableRoyaltiesInitializable,
    ReentrancyGuard
{
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    // Whether this contract is mintable.
    bool private _mintable;

    // Specify how long a signature from cosigner is valid for, recommend 300 seconds.
    uint64 private immutable _timestampExpirySeconds = 300;

    // The address of the cosigner server.
    address private _cosigner;

    // The crossmint address. Need to set if using crossmint.
    address private _crossmintAddress;

    // The total mintable supply.
    uint256 internal _maxMintableSupply;

    // Global wallet limit, across all stages.
    uint256 private _globalWalletLimit;

    // Current base URI.
    string private _currentBaseURI;

    // The suffix for the token URL, e.g. ".json".
    string private _tokenURISuffix;

    // The uri for the storefront-level metadata for better indexing. e.g. "ipfs://UyNGgv3jx2HHfBjQX9RnKtxj2xv2xQDtbVXoRi5rJ31234"
    string private _contractURI;

    // Mint stage infomation. See MintStageInfo for details.
    MintStageInfo[] private _mintStages;

    // Minted count per stage per wallet.
    mapping(uint256 => mapping(address => uint32))
        private _stageMintedCountsPerWallet;

    // Minted count per stage.
    mapping(uint256 => uint256) private _stageMintedCounts;

    // Address of ERC-20 token used to pay for minting. If 0 address, use native currency.
    address private _mintCurrency;

    // Total mint fee
    uint256 private _totalMintFee;

    // Fund receiver
    address private _fundReceiver;

    // Authorized minters
    mapping(address => bool) private _authorizedMinters;

    uint256 public constant VERSION = 2;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function initialize(
        string calldata name,
        string calldata symbol
    ) external initializerERC721A initializer {
        __ERC721ACQueryableInitializable_init(name, symbol);
    }

    function setup(
        string calldata tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address mintCurrency,
        address fundReceiver,
        address crossmintAddress,
        MintStageInfo[] calldata initialStages,
        address defaultRoyaltyReceiver,
        uint96 defaultRoyaltyFeeNumerator
    ) external onlyOwner {
        if (globalWalletLimit > maxMintableSupply)
            revert GlobalWalletLimitOverflow();
        _mintable = true;
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
        _tokenURISuffix = tokenURISuffix;
        _mintCurrency = mintCurrency;
        _fundReceiver = fundReceiver;
        _crossmintAddress = crossmintAddress;
        
        if (initialStages.length > 0) {
            _setStages(initialStages);
        }

        setDefaultRoyalty(defaultRoyaltyReceiver, defaultRoyaltyFeeNumerator);
    }

    function _setStages(MintStageInfo[] calldata newStages) internal {
        delete _mintStages;

        for (uint256 i = 0; i < newStages.length; ) {
            if (i >= 1) {
                if (
                    newStages[i].startTimeUnixSeconds <
                    newStages[i - 1].endTimeUnixSeconds +
                        _timestampExpirySeconds
                ) {
                    revert InsufficientStageTimeGap();
                }
            }
            _assertValidStartAndEndTimestamp(
                newStages[i].startTimeUnixSeconds,
                newStages[i].endTimeUnixSeconds
            );
            _mintStages.push(
                MintStageInfo({
                    price: newStages[i].price,
                    mintFee: newStages[i].mintFee,
                    walletLimit: newStages[i].walletLimit,
                    merkleRoot: newStages[i].merkleRoot,
                    maxStageSupply: newStages[i].maxStageSupply,
                    startTimeUnixSeconds: newStages[i].startTimeUnixSeconds,
                    endTimeUnixSeconds: newStages[i].endTimeUnixSeconds
                })
            );
            emit UpdateStage(
                i,
                newStages[i].price,
                newStages[i].mintFee,
                newStages[i].walletLimit,
                newStages[i].merkleRoot,
                newStages[i].maxStageSupply,
                newStages[i].startTimeUnixSeconds,
                newStages[i].endTimeUnixSeconds
            );

            unchecked {
                ++i;
            }
        }
    }

    function setStages(MintStageInfo[] calldata newStages) external onlyOwner {
        _setStages(newStages);
    }

    /**
     * @dev Returns whether mintable.
     */
    modifier canMint() {
        if (!_mintable) revert NotMintable();
        _;
    }

    /**
     * @dev Returns whether it has enough supply for the given qty.
     */
    modifier hasSupply(uint256 qty) {
        if (totalSupply() + qty > _maxMintableSupply) revert NoSupplyLeft();
        _;
    }

    /**
     * @dev Returns whether the msg sender is authorized to mint.
     */
    modifier onlyAuthorizedMinter() {
        if (_authorizedMinters[_msgSender()] != true) revert NotAuthorized();
        _;
    }

    /**
     * @dev Returns cosign nonce.
     */
    function getCosignNonce(address minter) public view returns (uint256) {
        return _numberMinted(minter);
    }

    /**
     * @dev Sets cosigner.
     */
    function setCosigner(address cosigner) external onlyOwner {
        _cosigner = cosigner;
        emit SetCosigner(cosigner);
    }

    /**
     * @dev Sets crossmint address if using crossmint. This allows the specified address to call `crossmint`.
     */
    function setCrossmintAddress(address crossmintAddress) external onlyOwner {
        _crossmintAddress = crossmintAddress;
        emit SetCrossmintAddress(crossmintAddress);
    }

    /**
     * @dev Add authorized minter. Can only be called by contract owner.
     */
    function addAuthorizedMinter(address minter) external onlyOwner {
        _authorizedMinters[minter] = true;
    }

    /**
     * @dev Remove authorized minter. Can only be called by contract owner.
     */
    function removeAuthorizedMinter(address minter) external onlyOwner {
        _authorizedMinters[minter] = false;
    }

    /**
     * @dev Gets whether mintable.
     */
    function getMintable() external view returns (bool) {
        return _mintable;
    }

    /**
     * @dev Sets mintable.
     */
    function setMintable(bool mintable) external onlyOwner {
        _mintable = mintable;
        emit SetMintable(mintable);
    }

    /**
     * @dev Returns number of stages.
     */
    function getNumberStages() external view override returns (uint256) {
        return _mintStages.length;
    }

    /**
     * @dev Returns maximum mintable supply.
     */
    function getMaxMintableSupply() external view override returns (uint256) {
        return _maxMintableSupply;
    }

    /**
     * @dev Sets maximum mintable supply.
     *
     * New supply cannot be larger than the old.
     */
    function setMaxMintableSupply(
        uint256 maxMintableSupply
    ) external virtual onlyOwner {
        if (maxMintableSupply > _maxMintableSupply) {
            revert CannotIncreaseMaxMintableSupply();
        }
        _maxMintableSupply = maxMintableSupply;
        emit SetMaxMintableSupply(maxMintableSupply);
    }

    /**
     * @dev Returns global wallet limit. This is the max number of tokens can be minted by one wallet.
     */
    function getGlobalWalletLimit() external view override returns (uint256) {
        return _globalWalletLimit;
    }

    /**
     * @dev Sets global wallet limit.
     */
    function setGlobalWalletLimit(
        uint256 globalWalletLimit
    ) external onlyOwner {
        if (globalWalletLimit > _maxMintableSupply)
            revert GlobalWalletLimitOverflow();
        _globalWalletLimit = globalWalletLimit;
        emit SetGlobalWalletLimit(globalWalletLimit);
    }

    /**
     * @dev Returns number of minted token for a given address.
     */
    function totalMintedByAddress(
        address a
    ) external view virtual override returns (uint256) {
        return _numberMinted(a);
    }

    /**
     * @dev Returns info for one stage specified by index (starting from 0).
     */
    function getStageInfo(
        uint256 index
    ) external view override returns (MintStageInfo memory, uint32, uint256) {
        if (index >= _mintStages.length) {
            revert InvalidStage();
        }
        uint32 walletMinted = _stageMintedCountsPerWallet[index][msg.sender];
        uint256 stageMinted = _stageMintedCounts[index];
        return (_mintStages[index], walletMinted, stageMinted);
    }

    /**
     * @dev Returns mint currency address.
     */
    function getMintCurrency() external view returns (address) {
        return _mintCurrency;
    }


    /**
     * @dev Mints token(s).
     *
     * qty - number of tokens to mint
     * proof - the merkle proof generated on client side. This applies if using whitelist.
     * timestamp - the current timestamp
     * signature - the signature from cosigner if using cosigner.
     */
    function mint(
        uint32 qty,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable virtual nonReentrant {
        _mintInternal(qty, msg.sender, 0, proof, timestamp, signature);
    }

    /**
     * @dev Mints token(s) with limit.
     *
     * qty - number of tokens to mint
     * limit - limit for the given minter
     * proof - the merkle proof generated on client side. This applies if using whitelist.
     * timestamp - the current timestamp
     * signature - the signature from cosigner if using cosigner.
     */
    function mintWithLimit(
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable virtual nonReentrant {
        _mintInternal(qty, msg.sender, limit, proof, timestamp, signature);
    }

    /**
     * @dev Mints token(s) through crossmint. This function is supposed to be called by crossmint.
     *
     * qty - number of tokens to mint
     * to - the address to mint tokens to
     * proof - the merkle proof generated on client side. This applies if using whitelist.
     * timestamp - the current timestamp
     * signature - the signature from cosigner if using cosigner.
     */
    function crossmint(
        uint32 qty,
        address to,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable nonReentrant {
        if (_crossmintAddress == address(0)) revert CrossmintAddressNotSet();

        // Check the caller is Crossmint
        if (msg.sender != _crossmintAddress) revert CrossmintOnly();

        _mintInternal(qty, to, 0, proof, timestamp, signature);
    }

    /**
     * @dev Authorized mints token(s) with limit
     *
     * qty - number of tokens to mint
     * to - the address to mint tokens to
     * limit - limit for the given minter
     * proof - the merkle proof generated on client side. This applies if using whitelist.
     * timestamp - the current timestamp
     * signature - the signature from cosigner if using cosigner.
     */
    function authorizedMint(
        uint32 qty,
        address to,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable onlyAuthorizedMinter {
        _mintInternal(qty, to, limit, proof, timestamp, signature);
    }

    /**
     * @dev Implementation of minting.
     */
    function _mintInternal(
        uint32 qty,
        address to,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) internal canMint hasSupply(qty) {
        uint64 stageTimestamp = uint64(block.timestamp);
        bool waiveMintFee = false;

        if (_cosigner != address(0)) {
            waiveMintFee = assertValidCosign(
                msg.sender,
                qty,
                timestamp,
                signature
            );
            _assertValidTimestamp(timestamp);
            stageTimestamp = timestamp;
        }

        uint256 activeStage = getActiveStageFromTimestamp(stageTimestamp);
        MintStageInfo memory stage = _mintStages[activeStage];

        uint80 adjustedMintFee = waiveMintFee ? 0 : stage.mintFee;

        // Check value if minting with ETH
        if (
            _mintCurrency == address(0) &&
            msg.value < (stage.price + adjustedMintFee) * qty
        ) revert NotEnoughValue();

        // Check stage supply if applicable
        if (stage.maxStageSupply > 0) {
            if (_stageMintedCounts[activeStage] + qty > stage.maxStageSupply)
                revert StageSupplyExceeded();
        }

        // Check global wallet limit if applicable
        if (_globalWalletLimit > 0) {
            if (_numberMinted(to) + qty > _globalWalletLimit)
                revert WalletGlobalLimitExceeded();
        }

        // Check wallet limit for stage if applicable, limit == 0 means no limit enforced
        if (stage.walletLimit > 0) {
            if (
                _stageMintedCountsPerWallet[activeStage][to] + qty >
                stage.walletLimit
            ) revert WalletStageLimitExceeded();
        }

        // Check merkle proof if applicable, merkleRoot == 0x00...00 means no proof required
        if (stage.merkleRoot != 0) {
            if (
                MerkleProof.processProof(
                    proof,
                    keccak256(abi.encodePacked(to, limit))
                ) != stage.merkleRoot
            ) revert InvalidProof();

            // Verify merkle proof mint limit
            if (
                limit > 0 &&
                _stageMintedCountsPerWallet[activeStage][to] + qty > limit
            ) {
                revert WalletStageLimitExceeded();
            }
        }

        if (_mintCurrency != address(0)) {
            // ERC20 mint payment
            IERC20(_mintCurrency).safeTransferFrom(
                msg.sender,
                address(this),
                (stage.price + adjustedMintFee) * qty
            );
        }

        _totalMintFee += adjustedMintFee * qty;

        _stageMintedCountsPerWallet[activeStage][to] += qty;
        _stageMintedCounts[activeStage] += qty;
        _safeMint(to, qty);
    }

    /**
     * @dev Mints token(s) by owner.
     *
     * NOTE: This function bypasses validations thus only available for owner.
     * This is typically used for owner to  pre-mint or mint the remaining of the supply.
     */
    function ownerMint(
        uint32 qty,
        address to
    ) external onlyOwner hasSupply(qty) {
        _safeMint(to, qty);
    }

    /**
     * @dev Withdraws funds by owner.
     */
    function withdraw() external onlyOwner {
        (bool success, ) = MINT_FEE_RECEIVER.call{value: _totalMintFee}("");
        if (!success) revert TransferFailed();
        _totalMintFee = 0;

        uint256 remainingValue = address(this).balance;
        (success, ) = _fundReceiver.call{value: remainingValue}("");
        if (!success) revert WithdrawFailed();

        emit Withdraw(_totalMintFee + remainingValue);
    }

    /**
     * @dev Withdraws ERC-20 funds by owner.
     */
    function withdrawERC20() external onlyOwner {
        if (_mintCurrency == address(0)) revert WrongMintCurrency();

        IERC20(_mintCurrency).safeTransfer(MINT_FEE_RECEIVER, _totalMintFee);
        _totalMintFee = 0;

        uint256 remaining = IERC20(_mintCurrency).balanceOf(address(this));
        IERC20(_mintCurrency).safeTransfer(_fundReceiver, remaining);

        emit WithdrawERC20(_mintCurrency, _totalMintFee + remaining);
    }

    /**
     * @dev Sets token base URI.
     */
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _currentBaseURI = baseURI;
        emit SetBaseURI(baseURI);
    }

    /**
     * @dev Sets token URI suffix. e.g. ".json".
     */
    function setTokenURISuffix(string calldata suffix) external onlyOwner {
        _tokenURISuffix = suffix;
    }

    /**
     * @dev Returns token URI for a given token id.
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721AUpgradeable, IERC721AUpgradeable)
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _currentBaseURI;
        return
            bytes(baseURI).length != 0
                ? string(
                    abi.encodePacked(
                        baseURI,
                        _toString(tokenId),
                        _tokenURISuffix
                    )
                )
                : "";
    }

    /**
     * @dev Returns data hash for the given minter, qty, waiveMintFee and timestamp.
     */
    function getCosignDigest(
        address minter,
        uint32 qty,
        bool waiveMintFee,
        uint64 timestamp
    ) public view returns (bytes32) {
        if (_cosigner == address(0)) revert CosignerNotSet();
        return
            MessageHashUtils.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        address(this),
                        minter,
                        qty,
                        waiveMintFee,
                        _cosigner,
                        timestamp,
                        _chainID(),
                        getCosignNonce(minter)
                    )
                )
            );
    }

    /**
     * @dev Returns URI for the collection-level metadata.
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
     * @dev Set the URI for the collection-level metadata.
     */
    function setContractURI(string calldata uri) external onlyOwner {
        _contractURI = uri;
    }

    function assertValidCosign(
        address minter,
        uint32 qty,
        uint64 timestamp,
        bytes memory signature
    ) public view returns (bool) {
        if (
            SignatureChecker.isValidSignatureNow(
                _cosigner,
                getCosignDigest(
                    minter,
                    qty,
                    /* waiveMintFee= */ true,
                    timestamp
                ),
                signature
            )
        ) {
            return true;
        }

        if (
            SignatureChecker.isValidSignatureNow(
                _cosigner,
                getCosignDigest(
                    minter,
                    qty,
                    /* waiveMintFee= */ false,
                    timestamp
                ),
                signature
            )
        ) {
            return false;
        }

        revert InvalidCosignSignature();
    }

    /**
     * @dev Returns the current active stage based on timestamp.
     */
    function getActiveStageFromTimestamp(
        uint64 timestamp
    ) public view returns (uint256) {
        for (uint256 i = 0; i < _mintStages.length; ) {
            if (
                timestamp >= _mintStages[i].startTimeUnixSeconds &&
                timestamp < _mintStages[i].endTimeUnixSeconds
            ) {
                return i;
            }
            unchecked {
                ++i;
            }
        }
        revert InvalidStage();
    }

    /**
     * @dev Validates the timestamp is not expired.
     */
    function _assertValidTimestamp(uint64 timestamp) internal view {
        if (timestamp < block.timestamp - _timestampExpirySeconds)
            revert TimestampExpired();
    }

    /**
     * @dev Validates the start timestamp is before end timestamp. Used when updating stages.
     */
    function _assertValidStartAndEndTimestamp(
        uint64 start,
        uint64 end
    ) internal pure {
        if (start >= end) revert InvalidStartAndEndTimestamp();
    }

    /**
     * @dev Returns chain id.
     */
    function _chainID() private view returns (uint256 chainID) {
        assembly {
            chainID := chainid()
        }
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called 
     * @notice for transaction simulation. 
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    function _tokenType() internal pure override returns(uint16) {
        return uint16(721);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC2981, IERC721AUpgradeable, ERC721ACQueryableInitializable) returns (bool) {
        return super.supportsInterface(interfaceId) ||
        ERC2981.supportsInterface(interfaceId) ||
        ERC721ACQueryableInitializable.supportsInterface(interfaceId);
    }
}
