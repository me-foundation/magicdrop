//SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {ERC721A, IERC721A} from "erc721a/contracts/ERC721A.sol";

import {ERC721ACloneable} from "contracts/nft/erc721m/clones/ERC721ACloneable.sol";
import {ERC721ACQueryableInitializable} from "contracts/nft/creator-token-standards/ERC721ACQueryableInitializable.sol";
import {ERC721MStorageV1_0_2 as ERC721MStorage} from "contracts/nft/erc721m/ERC721MStorageV1_0_2.sol";
import {MINT_FEE_RECEIVER} from "contracts/utils/Constants.sol";
import {MintStageInfo, SetupConfig} from "contracts/nft/erc721m/Types.sol";
import {IERC721MInitializableV1_0_2 as IERC721MInitializable} from "contracts/nft/erc721m/interfaces/IERC721MInitializableV1_0_2.sol";
import {Cosignable} from "contracts/common/Cosignable.sol";
import {AuthorizedMinterControl} from "contracts/common/AuthorizedMinterControl.sol";

/// @title ERC721CMInitializableV1_0_2
/// @notice An initializable ERC721AC contract with multi-stage minting, royalties, and authorized minters
/// @dev Implements ERC721ACQueryable, ERC2981, Ownable, ReentrancyGuard, and custom minting logic
contract ERC721CMInitializableV1_0_2 is
    IERC721MInitializable,
    ERC721ACQueryableInitializable,
    ERC2981,
    Ownable,
    ReentrancyGuard,
    Cosignable,
    AuthorizedMinterControl,
    ERC721MStorage
{
    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @dev Disables initializers for the implementation contract.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param name The name of the token collection
    /// @param symbol The symbol of the token collection
    /// @param initialOwner The address of the initial owner
    function initialize(string calldata name, string calldata symbol, address initialOwner, uint256 mintFee) external initializer {
        if (initialOwner == address(0)) {
            revert InitialOwnerCannotBeZero();
        }

        __ERC721ACQueryableInitializable_init(name, symbol);
        _initializeOwner(initialOwner);
        _mintFee = mintFee;
    }

    /*==============================================================
    =                             META                             =
    ==============================================================*/

    /// @notice Returns the contract name and version
    /// @return The contract name and version as strings
    function contractNameAndVersion() public pure returns (string memory, string memory) {
        return ("ERC721CMInitializable", "1.0.2");
    }

    /// @notice Gets the token URI for a specific token ID
    /// @param tokenId The ID of the token
    /// @return The token URI
    function tokenURI(uint256 tokenId) public view override(ERC721ACloneable, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _currentBaseURI;
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId), _tokenURISuffix)) : "";
    }

    /// @notice Gets the contract URI
    /// @return The contract URI
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /*==============================================================
    =                             MODIFIERS                        =
    ==============================================================*/

    /// @notice Modifier to check if the contract is mintable
    modifier canMint() {
        if (!_mintable) revert NotMintable();
        _;
    }

    /// @notice Modifier to check if the total supply is enough
    /// @param qty The quantity to mint
    modifier hasSupply(uint256 qty) {
        if (totalSupply() + qty > _maxMintableSupply) revert NoSupplyLeft();
        _;
    }

    /*==============================================================
    =                     PUBLIC WRITE METHODS                     =
    ==============================================================*/

    /// @notice Mints tokens for the caller
    /// @param qty The quantity to mint
    /// @param limit The minting limit for the caller (used in merkle proofs)
    /// @param proof The merkle proof for allowlist minting
    /// @param timestamp The timestamp for the minting action (used in cosigning)
    /// @param signature The cosigner's signature
    function mint(uint32 qty, uint32 limit, bytes32[] calldata proof, uint256 timestamp, bytes calldata signature)
        external
        payable
        virtual
        nonReentrant
    {
        _mintInternal(qty, msg.sender, limit, proof, timestamp, signature);
    }

    /// @notice Allows authorized minters to mint tokens for a specified address
    /// @param to The address to mint tokens for
    /// @param qty The quantity to mint
    /// @param limit The minting limit for the recipient (used in merkle proofs)
    /// @param proof The merkle proof for allowlist minting
    /// @param timestamp The timestamp for the minting action (used in cosigning)
    /// @param signature The cosigner's signature
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

    /// @notice Burns a specific token.
    /// @dev Only callable by the token owner or an approved operator. The token must exist.
    /// @param tokenId The ID of the token to burn.
    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Gets the stage info for a given stage index
    /// @param index The stage index
    /// @return The stage info, wallet minted count, and stage minted count
    function getStageInfo(uint256 index) external view override returns (MintStageInfo memory, uint32, uint256) {
        if (index >= _mintStages.length) {
            revert InvalidStage();
        }
        uint32 walletMinted = _stageMintedCountsPerWallet[index][msg.sender];
        uint256 stageMinted = _stageMintedCounts[index];
        return (_mintStages[index], walletMinted, stageMinted);
    }

    /// @notice Gets the contract configuration
    /// @return The contract configuration
    function getConfig() external view returns (SetupConfig memory) {
        SetupConfig memory config;
        config.maxSupply = _maxMintableSupply;
        config.walletLimit = _globalWalletLimit;
        config.baseURI = _currentBaseURI;
        config.contractURI = _contractURI;
        config.stages = _mintStages;
        config.payoutRecipient = _fundReceiver;
        config.royaltyRecipient = _royaltyRecipient;
        config.royaltyBps = _royaltyBps;
        config.mintFee = _mintFee;
        return config;
    }

    /// @notice Gets the mint currency address
    /// @return The address of the mint currency
    function getMintCurrency() external view returns (address) {
        return _mintCurrency;
    }

    /// @notice Gets the cosign nonce for a specific minter
    /// @param minter The address of the minter
    /// @return The cosign nonce
    function getCosignNonce(address minter) public view returns (uint256) {
        return _numberMinted(minter);
    }

    /// @notice Gets the mintable status
    /// @return The mintable status
    function getMintable() external view returns (bool) {
        return _mintable;
    }

    /// @notice Gets the number of minting stages
    /// @return The number of minting stages
    function getNumberStages() external view override returns (uint256) {
        return _mintStages.length;
    }

    /// @notice Gets the maximum mintable supply
    /// @return The maximum mintable supply
    function getMaxMintableSupply() external view override returns (uint256) {
        return _maxMintableSupply;
    }

    /// @notice Gets the global wallet limit
    /// @return The global wallet limit
    function getGlobalWalletLimit() external view override returns (uint256) {
        return _globalWalletLimit;
    }

    /// @notice Gets the total minted count for a specific address
    /// @param a The address to get the minted count for
    /// @return The total minted count
    function totalMintedByAddress(address a) external view virtual override returns (uint256) {
        return _numberMinted(a);
    }

    /// @notice Gets the active stage from the timestamp
    /// @param timestamp The timestamp to get the active stage from
    /// @return The active stage
    function getActiveStageFromTimestamp(uint256 timestamp) public view returns (uint256) {
        for (uint256 i = 0; i < _mintStages.length; i++) {
            if (timestamp >= _mintStages[i].startTimeUnixSeconds && timestamp < _mintStages[i].endTimeUnixSeconds) {
                return i;
            }
        }
        revert InvalidStage();
    }

    /// @notice Checks if the contract is setup locked
    /// @return Whether the contract is setup locked
    function isSetupLocked() external view returns (bool) {
        return _setupLocked;
    }

    /// @notice Checks if the contract is transferable
    /// @return Whether the contract is transferable
    function isTransferable() public view returns (bool) {
        return _transferable;
    }

    /// @notice Checks if the contract supports a given interface
    /// @param interfaceId The interface identifier
    /// @return True if the contract supports the interface, false otherwise
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC2981, IERC721A, ERC721ACQueryableInitializable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId)
            || ERC721ACQueryableInitializable.supportsInterface(interfaceId);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Sets up the contract with initial parameters
    /// @param baseURI The base URI for the token URIs
    /// @param tokenURISuffix The suffix for the token URIs
    /// @param maxMintableSupply The maximum mintable supply
    /// @param globalWalletLimit The global wallet limit
    /// @param mintCurrency The address of the mint currency
    /// @param fundReceiver The address to receive funds
    /// @param initialStages The initial mint stages
    /// @param royaltyReceiver The address to receive royalties
    /// @param royaltyFeeNumerator The royalty fee numerator
    function setup(
        string calldata baseURI,
        string calldata tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address mintCurrency,
        address fundReceiver,
        MintStageInfo[] calldata initialStages,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external onlyOwner {
        if (_setupLocked) {
            revert ContractAlreadySetup();
        }

        if (globalWalletLimit > maxMintableSupply) {
            revert GlobalWalletLimitOverflow();
        }

        _setupLocked = true;
        _mintable = true;
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
        _mintCurrency = mintCurrency;
        _fundReceiver = fundReceiver;
        _currentBaseURI = baseURI;
        _tokenURISuffix = tokenURISuffix;
        _transferable = true;
        _setTimestampExpirySeconds(300); // 5 minutes

        if (initialStages.length > 0) {
            _setStages(initialStages);
        }

        if (royaltyReceiver != address(0)) {
            setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
            _royaltyBps = royaltyFeeNumerator;
            _royaltyRecipient = royaltyReceiver;
        }
    }

    /// @notice Adds an authorized minter
    /// @param minter The address to add as an authorized minter
    function addAuthorizedMinter(address minter) external override onlyOwner {
        _addAuthorizedMinter(minter);
    }

    /// @notice Removes an authorized minter
    /// @param minter The address to remove as an authorized minter
    function removeAuthorizedMinter(address minter) external override onlyOwner {
        _removeAuthorizedMinter(minter);
    }

    /// @notice Sets the cosigner address
    /// @param cosigner The address to set as the cosigner
    function setCosigner(address cosigner) external override onlyOwner {
        _setCosigner(cosigner);
    }

    /// @notice Sets the timestamp expiry seconds
    /// @param timestampExpirySeconds The expiry time in seconds for timestamps
    function setTimestampExpirySeconds(uint256 timestampExpirySeconds) external override onlyOwner {
        _setTimestampExpirySeconds(timestampExpirySeconds);
    }

    /// @notice Sets the mint stages
    /// @param newStages The new mint stages to set
    function setStages(MintStageInfo[] calldata newStages) external onlyOwner {
        _setStages(newStages);
    }

    /// @notice Sets the mintable status
    /// @param mintable The mintable status to set
    function setMintable(bool mintable) external onlyOwner {
        _mintable = mintable;
        emit SetMintable(mintable);
    }

    /// @notice Sets the default royalty for the contract
    /// @param receiver The address to receive royalties
    /// @param feeNumerator The royalty fee numerator
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyOwner {
        super._setDefaultRoyalty(receiver, feeNumerator);
        _royaltyBps = feeNumerator;
        _royaltyRecipient = receiver;
        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    /// @notice Sets the maximum mintable supply
    /// @param maxMintableSupply The maximum mintable supply to set
    function setMaxMintableSupply(uint256 maxMintableSupply) external virtual onlyOwner {
        if (maxMintableSupply > _maxMintableSupply) {
            revert CannotIncreaseMaxMintableSupply();
        }
        _maxMintableSupply = maxMintableSupply;
        emit SetMaxMintableSupply(maxMintableSupply);
    }

    /// @notice Sets the global wallet limit
    /// @param globalWalletLimit The global wallet limit to set
    function setGlobalWalletLimit(uint256 globalWalletLimit) external onlyOwner {
        if (globalWalletLimit > _maxMintableSupply) {
            revert GlobalWalletLimitOverflow();
        }
        _globalWalletLimit = globalWalletLimit;
        emit SetGlobalWalletLimit(globalWalletLimit);
    }

    /// @notice Allows the owner to mint tokens for a specific address
    /// @param qty The quantity to mint
    /// @param to The address to mint tokens for
    function ownerMint(uint32 qty, address to) external onlyOwner hasSupply(qty) {
        _safeMint(to, qty);
    }

    /// @notice Withdraws the total mint fee and remaining balance from the contract
    /// @dev Can only be called by the owner
    function withdraw() external onlyOwner {
        (bool success,) = MINT_FEE_RECEIVER.call{value: _totalMintFee}("");
        if (!success) revert TransferFailed();
        _totalMintFee = 0;

        uint256 remainingValue = address(this).balance;
        (success,) = _fundReceiver.call{value: remainingValue}("");
        if (!success) revert WithdrawFailed();

        emit Withdraw(_totalMintFee + remainingValue);
    }

    /// @notice Withdraws ERC20 tokens from the contract
    /// @dev Can only be called by the owner
    function withdrawERC20() external onlyOwner {
        if (_mintCurrency == address(0)) revert WrongMintCurrency();

        uint256 totalFee = _totalMintFee;
        uint256 remaining = SafeTransferLib.balanceOf(_mintCurrency, address(this));

        if (remaining < totalFee) revert InsufficientBalance();

        _totalMintFee = 0;
        uint256 totalAmount = totalFee + remaining;

        SafeTransferLib.safeTransfer(_mintCurrency, MINT_FEE_RECEIVER, totalFee);
        SafeTransferLib.safeTransfer(_mintCurrency, _fundReceiver, remaining);

        emit WithdrawERC20(_mintCurrency, totalAmount);
    }

    /// @notice Sets the base URI for the token URIs
    /// @param baseURI The base URI to set
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _currentBaseURI = baseURI;
        emit SetBaseURI(baseURI);
    }

    /// @notice Sets the token URI suffix
    /// @param suffix The suffix to set
    function setTokenURISuffix(string calldata suffix) external onlyOwner {
        _tokenURISuffix = suffix;
    }

    /// @notice Sets the contract URI
    /// @param uri The URI to set
    function setContractURI(string calldata uri) external onlyOwner {
        _contractURI = uri;
        emit SetContractURI(uri);
    }

    /// @notice Sets whether tokens are transferable
    /// @param transferable True if tokens should be transferable, false otherwise
    function setTransferable(bool transferable) external onlyOwner {
        if (_transferable == transferable) revert TransferableAlreadySet();

        _transferable = transferable;
        emit SetTransferable(transferable);
    }

    /*==============================================================
    =                      INTERNAL HELPERS                        =
    ==============================================================*/

    /// @notice Internal function to handle minting logic
    /// @param qty The quantity to mint
    /// @param to The address to mint tokens for
    /// @param limit The minting limit for the recipient (used in merkle proofs)
    /// @param proof The merkle proof for allowlist minting
    /// @param timestamp The timestamp for the minting action (used in cosigning)
    /// @param signature The cosigner's signature
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

        uint256 adjustedMintFee = waiveMintFee ? 0 : _mintFee;

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
            if (!MerkleProofLib.verify(proof, stage.merkleRoot, keccak256(abi.encodePacked(to, limit)))) {
                revert InvalidProof();
            }

            // Verify merkle proof mint limit
            if (limit > 0 && _stageMintedCountsPerWallet[activeStage][to] + qty > limit) {
                revert WalletStageLimitExceeded();
            }
        }

        if (_mintCurrency != address(0)) {
            // ERC20 mint payment
            SafeTransferLib.safeTransferFrom(
                _mintCurrency, msg.sender, address(this), (stage.price + adjustedMintFee) * qty
            );
        }

        _totalMintFee += adjustedMintFee * qty;

        _stageMintedCountsPerWallet[activeStage][to] += qty;
        _stageMintedCounts[activeStage] += qty;
        _safeMint(to, qty);
    }

    /// @notice Sets the mint stages
    /// @param newStages The new mint stages to set
    function _setStages(MintStageInfo[] calldata newStages) internal {
        delete _mintStages;

        for (uint256 i = 0; i < newStages.length;) {
            if (i >= 1) {
                if (
                    newStages[i].startTimeUnixSeconds
                        < newStages[i - 1].endTimeUnixSeconds + getTimestampExpirySeconds()
                ) {
                    revert InsufficientStageTimeGap();
                }
            }
            _assertValidStartAndEndTimestamp(newStages[i].startTimeUnixSeconds, newStages[i].endTimeUnixSeconds);
            _mintStages.push(
                MintStageInfo({
                    price: newStages[i].price,
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

    /// @notice Validates the start and end timestamps for a stage
    /// @param start The start timestamp
    /// @param end The end timestamp
    function _assertValidStartAndEndTimestamp(uint256 start, uint256 end) internal pure {
        if (start >= end) revert InvalidStartAndEndTimestamp();
    }

    /// @notice Requires the caller to be the contract owner
    function _requireCallerIsContractOwner() internal view override {
        return _checkOwner();
    }

    /// @dev Overriden to prevent double-initialization of the owner.
    function _guardInitializeOwner() internal pure virtual override returns (bool) {
        return true;
    }

    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        virtual
        override
    {
        // If the transfer is not from a mint or burn, revert if not transferable
        if (from != address(0) && to != address(0) && !_transferable) {
            revert NotTransferable();
        }

        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
