//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "../creator-token-standards/ERC721ACQueryable.sol";
import "./interfaces/IERC721M.sol";
import "../../utils/Constants.sol";
import "../../common/Cosignable.sol";
import "../../common/AuthorizedMinterControl.sol";

/**
 * @title ERC721CM
 *
 * @dev ERC721ACQueryable and ERC721C subclass with MagicEden launchpad features including
 *  - multiple minting stages with time-based auto stage switch
 *  - global and stage wallet-level minting limit
 *  - whitelist using merkle tree
 *  - authorized minter support
 *  - anti-botting
 */
contract ERC721CM is IERC721M, ERC721ACQueryable, Ownable, ReentrancyGuard, Cosignable, AuthorizedMinterControl {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    // Whether this contract is mintable.
    bool private _mintable;

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
    mapping(uint256 => mapping(address => uint32)) private _stageMintedCountsPerWallet;

    // Minted count per stage.
    mapping(uint256 => uint256) private _stageMintedCounts;

    // Address of ERC-20 token used to pay for minting. If 0 address, use native currency.
    address private _mintCurrency;

    // Total mint fee
    uint256 private _totalMintFee;

    // Fund receiver
    address public immutable FUND_RECEIVER;

    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint256 timestampExpirySeconds,
        address mintCurrency,
        address fundReceiver
    ) Ownable(msg.sender) ERC721ACQueryable(collectionName, collectionSymbol) {
        if (globalWalletLimit > maxMintableSupply) {
            revert GlobalWalletLimitOverflow();
        }
        _mintable = true;
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
        _tokenURISuffix = tokenURISuffix;
        _mintCurrency = mintCurrency;
        FUND_RECEIVER = fundReceiver;

        _setCosigner(cosigner);
        _setTimestampExpirySeconds(timestampExpirySeconds);
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
     * @dev Returns cosign nonce.
     */
    function getCosignNonce(address minter) public view returns (uint256) {
        return _numberMinted(minter);
    }

    /**
     * @dev Add authorized minter. Can only be called by contract owner.
     */
    function addAuthorizedMinter(address minter) external override onlyOwner {
        _addAuthorizedMinter(minter);
    }

    /**
     * @dev Remove authorized minter. Can only be called by contract owner.
     */
    function removeAuthorizedMinter(address minter) external override onlyOwner {
        _removeAuthorizedMinter(minter);
    }

    /**
     * @dev Sets cosigner. Can only be called by contract owner.
     */
    function setCosigner(address cosigner) external override onlyOwner {
        _setCosigner(cosigner);
    }

    /**
     * @dev Sets timestamp expiry seconds. Can only be called by contract owner.
     */
    function setTimestampExpirySeconds(uint256 timestampExpirySeconds) external override onlyOwner {
        _setTimestampExpirySeconds(timestampExpirySeconds);
    }

    /**
     * @dev Sets stages in the format of an array of `MintStageInfo`.
     *
     * Following is an example of launch with two stages. The first stage is exclusive for whitelisted wallets
     * specified by merkle root.
     *    [{
     *      price: 10000000000000000000,
     *      maxStageSupply: 2000,
     *      walletLimit: 1,
     *      merkleRoot: 0x559fadeb887449800b7b320bf1e92d309f329b9641ac238bebdb74e15c0a5218,
     *      startTimeUnixSeconds: 1667768000,
     *      endTimeUnixSeconds: 1667771600,
     *     },
     *     {
     *      price: 20000000000000000000,
     *      maxStageSupply: 3000,
     *      walletLimit: 2,
     *      merkleRoot: 0,
     *      startTimeUnixSeconds: 1667771600,
     *      endTimeUnixSeconds: 1667775200,
     *     }
     * ]
     */
    function setStages(MintStageInfo[] calldata newStages) external onlyOwner {
        delete _mintStages;

        for (uint256 i = 0; i < newStages.length;) {
            if (i >= 1) {
                if (newStages[i].startTimeUnixSeconds < newStages[i - 1].endTimeUnixSeconds + getTimestampExpirySeconds()) {
                    revert InsufficientStageTimeGap();
                }
            }
            _assertValidStartAndEndTimestamp(newStages[i].startTimeUnixSeconds, newStages[i].endTimeUnixSeconds);
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
    function setMaxMintableSupply(uint256 maxMintableSupply) external virtual onlyOwner {
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
    function setGlobalWalletLimit(uint256 globalWalletLimit) external onlyOwner {
        if (globalWalletLimit > _maxMintableSupply) {
            revert GlobalWalletLimitOverflow();
        }
        _globalWalletLimit = globalWalletLimit;
        emit SetGlobalWalletLimit(globalWalletLimit);
    }

    /**
     * @dev Returns number of minted token for a given address.
     */
    function totalMintedByAddress(address a) external view virtual override returns (uint256) {
        return _numberMinted(a);
    }

    /**
     * @dev Returns info for one stage specified by index (starting from 0).
     */
    function getStageInfo(uint256 index) external view override returns (MintStageInfo memory, uint32, uint256) {
        if (index >= _mintStages.length) {
            revert("InvalidStage");
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
    function mint(uint32 qty, uint32 limit, bytes32[] calldata proof, uint256 timestamp, bytes calldata signature)
        external
        payable
        virtual
        nonReentrant
    {
        _mintInternal(qty, msg.sender, limit, proof, timestamp, signature);
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
        uint256 timestamp,
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
        uint256 timestamp,
        bytes calldata signature
    ) internal canMint hasSupply(qty) {
        uint256 stageTimestamp = block.timestamp;
        bool waiveMintFee = false;

        if (getCosigner() != address(0)) {
            waiveMintFee = assertValidCosign(msg.sender, qty, timestamp, signature, getCosignNonce(msg.sender));
            _assertValidTimestamp(timestamp);
            stageTimestamp = timestamp;
        }

        uint256 activeStage = getActiveStageFromTimestamp(stageTimestamp);
        MintStageInfo memory stage = _mintStages[activeStage];

        uint80 adjustedMintFee = waiveMintFee ? 0 : stage.mintFee;

        // Check value if minting with ETH
        if (_mintCurrency == address(0) && msg.value < (stage.price + adjustedMintFee) * qty) revert NotEnoughValue();

        // Check stage supply if applicable
        if (stage.maxStageSupply > 0) {
            if (_stageMintedCounts[activeStage] + qty > stage.maxStageSupply) {
                revert StageSupplyExceeded();
            }
        }

        // Check global wallet limit if applicable
        if (_globalWalletLimit > 0) {
            if (_numberMinted(to) + qty > _globalWalletLimit) {
                revert WalletGlobalLimitExceeded();
            }
        }

        // Check wallet limit for stage if applicable, limit == 0 means no limit enforced
        if (stage.walletLimit > 0) {
            if (_stageMintedCountsPerWallet[activeStage][to] + qty > stage.walletLimit) {
                revert WalletStageLimitExceeded();
            }
        }

        // Check merkle proof if applicable, merkleRoot == 0x00...00 means no proof required
        if (stage.merkleRoot != 0) {
            if (MerkleProof.processProof(proof, keccak256(abi.encodePacked(to, limit))) != stage.merkleRoot) {
                revert InvalidProof();
            }

            // Verify merkle proof mint limit
            if (limit > 0 && _stageMintedCountsPerWallet[activeStage][to] + qty > limit) {
                revert WalletStageLimitExceeded();
            }
        }

        if (_mintCurrency != address(0)) {
            IERC20(_mintCurrency).safeTransferFrom(msg.sender, address(this), (stage.price + adjustedMintFee) * qty);
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
    function ownerMint(uint32 qty, address to) external onlyOwner hasSupply(qty) {
        _safeMint(to, qty);
    }

    /**
     * @dev Withdraws funds by owner.
     */
    function withdraw() external onlyOwner {
        (bool success,) = MINT_FEE_RECEIVER.call{value: _totalMintFee}("");
        if (!success) revert TransferFailed();
        _totalMintFee = 0;

        uint256 remainingValue = address(this).balance;
        (success,) = FUND_RECEIVER.call{value: remainingValue}("");
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
        IERC20(_mintCurrency).safeTransfer(FUND_RECEIVER, remaining);

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
    function tokenURI(uint256 tokenId) public view override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _currentBaseURI;
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId), _tokenURISuffix)) : "";
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

    /**
     * @dev Returns the current active stage based on timestamp.
     */
    function getActiveStageFromTimestamp(uint256 timestamp) public view returns (uint256) {
        for (uint256 i = 0; i < _mintStages.length;) {
            if (timestamp >= _mintStages[i].startTimeUnixSeconds && timestamp < _mintStages[i].endTimeUnixSeconds) {
                return i;
            }
            unchecked {
                ++i;
            }
        }
        revert InvalidStage();
    }

    /**
     * @dev Validates the start timestamp is before end timestamp. Used when updating stages.
     */
    function _assertValidStartAndEndTimestamp(uint256 start, uint256 end) internal pure {
        if (start >= end) revert InvalidStartAndEndTimestamp();
    }

    /**
     * @dev Returns chain id.
     */
    function _chainID() private view returns (uint256) {
        uint256 chainID;
        /// @solidity memory-safe-assembly
        assembly {
            chainID := chainid()
        }
        return chainID;
    }

    function _requireCallerIsContractOwner() internal view virtual override {
        _checkOwner();
    }

    /**
     * @notice Returns the function selector for the transfer validator's validation function to be called
     * @notice for transaction simulation.
     */
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }
}
