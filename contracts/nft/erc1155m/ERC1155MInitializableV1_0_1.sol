//SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {
    ERC1155SupplyUpgradeable,
    ERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {MintStageInfo1155} from "../../common/Structs.sol";
import {MINT_FEE_RECEIVER} from "../../utils/Constants.sol";
import {IERC1155M} from "./interfaces/IERC1155M.sol";
import {ERC1155MStorage} from "./ERC1155MStorage.sol";
import {Cosignable} from "../../common/Cosignable.sol";
import {AuthorizedMinterControl} from "../../common/AuthorizedMinterControl.sol";

/// @title ERC1155MInitializableV1_0_1
/// @notice An initializable ERC1155 contract with multi-stage minting, royalties, and authorized minters
/// @dev Implements ERC1155, ERC2981, Ownable, ReentrancyGuard, and custom minting logic
contract ERC1155MInitializableV1_0_1 is
    IERC1155M,
    ERC1155SupplyUpgradeable,
    Ownable,
    ReentrancyGuard,
    ERC1155MStorage,
    ERC2981,
    Cosignable,
    AuthorizedMinterControl
{
    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @dev Disables initializers for the implementation contract.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param name_ The name of the token collection
    /// @param symbol_ The symbol of the token collection
    /// @param initialOwner The address of the initial owner
    function initialize(string calldata name_, string calldata symbol_, address initialOwner) external initializer {
        if (initialOwner == address(0)) {
            revert InitialOwnerCannotBeZero();
        }

        name = name_;
        symbol = symbol_;
        __ERC1155_init("");
        _initializeOwner(initialOwner);
    }

    /*==============================================================
    =                             META                             =
    ==============================================================*/

    /// @notice Returns the contract name and version
    /// @return The contract name and version as strings
    function contractNameAndVersion() public pure returns (string memory, string memory) {
        return ("ERC1155MInitializable", "1.0.1");
    }

    /*==============================================================
    =                         MODIFIERS                            =
    ==============================================================*/

    /// @dev Modifier to check if there's enough supply for minting
    /// @param tokenId The ID of the token to mint
    /// @param qty The quantity to mint
    modifier hasSupply(uint256 tokenId, uint256 qty) {
        if (_maxMintableSupply[tokenId] > 0 && totalSupply(tokenId) + qty > _maxMintableSupply[tokenId]) {
            revert NoSupplyLeft();
        }
        _;
    }

    /*==============================================================
    =                     PUBLIC WRITE METHODS                     =
    ==============================================================*/

    /// @notice Mints tokens for the caller
    /// @param tokenId The ID of the token to mint
    /// @param qty The quantity to mint
    /// @param limit The minting limit for the caller (used in merkle proofs)
    /// @param proof The merkle proof for allowlist minting
    /// @param timestamp The timestamp for the minting action (used in cosigning)
    /// @param signature The cosigner's signature
    function mint(
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint256 timestamp,
        bytes calldata signature
    ) external payable virtual nonReentrant {
        _mintInternal(msg.sender, tokenId, qty, limit, proof, timestamp, signature);
    }

    /// @notice Allows authorized minters to mint tokens for a specified address
    /// @param to The address to mint tokens for
    /// @param tokenId The ID of the token to mint
    /// @param qty The quantity to mint
    /// @param limit The minting limit for the recipient (used in merkle proofs)
    /// @param proof The merkle proof for allowlist minting
    function authorizedMint(address to, uint256 tokenId, uint32 qty, uint32 limit, bytes32[] calldata proof)
        external
        payable
        onlyAuthorizedMinter
    {
        _mintInternal(to, tokenId, qty, limit, proof, 0, bytes("0"));
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Gets the stage info, total minted, and stage minted for a specific stage
    /// @param stage The stage number
    /// @return The stage info, total minted by the caller, and stage minted by the caller
    function getStageInfo(uint256 stage)
        external
        view
        override
        returns (MintStageInfo1155 memory, uint256[] memory, uint256[] memory)
    {
        if (stage >= _mintStages.length) {
            revert InvalidStage();
        }
        uint256[] memory walletMinted = totalMintedByAddress(msg.sender);
        uint256[] memory stageMinted = _totalMintedByStageByAddress(stage, msg.sender);
        return (_mintStages[stage], walletMinted, stageMinted);
    }

    /// @notice Gets the number of minting stages
    /// @return The number of minting stages
    function getNumberStages() external view override returns (uint256) {
        return _mintStages.length;
    }

    /// @notice Gets the active stage based on a given timestamp
    /// @param timestamp The timestamp to check
    /// @return The active stage number
    function getActiveStageFromTimestamp(uint256 timestamp) public view returns (uint256) {
        for (uint256 i = 0; i < _mintStages.length; i++) {
            if (timestamp >= _mintStages[i].startTimeUnixSeconds && timestamp < _mintStages[i].endTimeUnixSeconds) {
                return i;
            }
        }
        revert InvalidStage();
    }

    /// @notice Gets the mint currency address
    /// @return The address of the mint currency
    function getMintCurrency() external view returns (address) {
        return _mintCurrency;
    }

    /// @notice Gets the cosign nonce for a specific minter and token ID
    /// @param minter The address of the minter
    /// @param tokenId The ID of the token
    /// @return The cosign nonce
    function getCosignNonce(address minter, uint256 tokenId) public view returns (uint256) {
        return totalMintedByAddress(minter)[tokenId];
    }

    /// @notice Gets the maximum mintable supply for a specific token ID
    /// @param tokenId The ID of the token
    /// @return The maximum mintable supply
    function getMaxMintableSupply(uint256 tokenId) external view override returns (uint256) {
        return _maxMintableSupply[tokenId];
    }

    /// @notice Gets the global wallet limit for a specific token ID
    /// @param tokenId The ID of the token
    /// @return The global wallet limit
    function getGlobalWalletLimit(uint256 tokenId) external view override returns (uint256) {
        return _globalWalletLimit[tokenId];
    }

    /// @notice Gets the total minted tokens for each token ID by a specific address
    /// @param account The address to check
    /// @return An array of total minted tokens for each token ID
    function totalMintedByAddress(address account) public view virtual override returns (uint256[] memory) {
        uint256[] memory totalMinted = new uint256[](_numTokens);
        uint256 numStages = _mintStages.length;
        for (uint256 token = 0; token < _numTokens; token++) {
            for (uint256 stage = 0; stage < numStages; stage++) {
                totalMinted[token] += _stageMintedCountsPerTokenPerWallet[stage][token][account];
            }
        }
        return totalMinted;
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
        virtual
        override(ERC2981, ERC1155Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId)
            || ERC1155Upgradeable.supportsInterface(interfaceId);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Sets up the contract with initial parameters
    /// @param uri_ The URI for token metadata
    /// @param maxMintableSupply Array of maximum mintable supply for each token ID
    /// @param globalWalletLimit Array of global wallet limits for each token ID
    /// @param mintCurrency The address of the mint currency
    /// @param fundReceiver The address to receive funds
    /// @param royaltyReceiver The address to receive royalties
    /// @param royaltyFeeNumerator The royalty fee numerator
    function setup(
        string calldata uri_,
        uint256[] memory maxMintableSupply,
        uint256[] memory globalWalletLimit,
        address mintCurrency,
        address fundReceiver,
        MintStageInfo1155[] calldata initialStages,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external onlyOwner {
        if (_setupLocked) {
            revert ContractAlreadySetup();
        }

        if (maxMintableSupply.length != globalWalletLimit.length) {
            revert InvalidLimitArgsLength();
        }

        for (uint256 i = 0; i < globalWalletLimit.length; i++) {
            if (maxMintableSupply[i] > 0 && globalWalletLimit[i] > maxMintableSupply[i]) {
                revert GlobalWalletLimitOverflow();
            }
        }

        _setupLocked = true;
        _numTokens = globalWalletLimit.length;
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
        _transferable = true;
        _mintCurrency = mintCurrency;
        _fundReceiver = fundReceiver;
        _setTimestampExpirySeconds(300); // 5 minutes

        _setURI(uri_);

        if (initialStages.length > 0) {
            _setStages(initialStages);
        }

        if (royaltyReceiver != address(0)) {
            setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
        }
    }

    function setStages(MintStageInfo1155[] calldata newStages) external onlyOwner {
        _setStages(newStages);
    }

    /// @notice Sets the minting stages
    /// @param newStages An array of new minting stages
    function _setStages(MintStageInfo1155[] calldata newStages) internal {
        delete _mintStages;

        for (uint256 i = 0; i < newStages.length; i++) {
            if (i >= 1) {
                if (
                    newStages[i].startTimeUnixSeconds
                        < newStages[i - 1].endTimeUnixSeconds + getTimestampExpirySeconds()
                ) {
                    revert InsufficientStageTimeGap();
                }
            }
            _assertValidStartAndEndTimestamp(newStages[i].startTimeUnixSeconds, newStages[i].endTimeUnixSeconds);
            _assertValidStageArgsLength(newStages[i]);

            _mintStages.push(
                MintStageInfo1155({
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
        }
    }

    /// @notice Sets the URI for token metadata
    /// @param newURI The new URI to set
    function setURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    /// @notice Sets whether tokens are transferable
    /// @param transferable True if tokens should be transferable, false otherwise
    function setTransferable(bool transferable) external onlyOwner {
        if (_transferable == transferable) revert TransferableAlreadySet();

        _transferable = transferable;
        emit SetTransferable(transferable);
    }

    /// @notice Sets the default royalty for the contract
    /// @param receiver The address to receive royalties
    /// @param feeNumerator The royalty fee numerator
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyOwner {
        super._setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    /// @notice Sets the royalty for a specific token
    /// @param tokenId The ID of the token
    /// @param receiver The address to receive royalties
    /// @param feeNumerator The royalty fee numerator
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) public onlyOwner {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit TokenRoyaltySet(tokenId, receiver, feeNumerator);
    }

    /// @notice Sets the maximum mintable supply for a specific token
    /// @param tokenId The ID of the token
    /// @param maxMintableSupply The new maximum mintable supply
    function setMaxMintableSupply(uint256 tokenId, uint256 maxMintableSupply) external virtual onlyOwner {
        if (tokenId >= _numTokens) {
            revert InvalidTokenId();
        }
        if (_maxMintableSupply[tokenId] != 0 && maxMintableSupply > _maxMintableSupply[tokenId]) {
            revert CannotIncreaseMaxMintableSupply();
        }
        if (maxMintableSupply < totalSupply(tokenId)) {
            revert NewSupplyLessThanTotalSupply();
        }
        _maxMintableSupply[tokenId] = maxMintableSupply;
        emit SetMaxMintableSupply(tokenId, maxMintableSupply);
    }

    /// @notice Sets the global wallet limit for a specific token
    /// @param tokenId The ID of the token
    /// @param globalWalletLimit The new global wallet limit
    function setGlobalWalletLimit(uint256 tokenId, uint256 globalWalletLimit) external onlyOwner {
        if (tokenId >= _numTokens) {
            revert InvalidTokenId();
        }
        if (_maxMintableSupply[tokenId] > 0 && globalWalletLimit > _maxMintableSupply[tokenId]) {
            revert GlobalWalletLimitOverflow();
        }
        _globalWalletLimit[tokenId] = globalWalletLimit;
        emit SetGlobalWalletLimit(tokenId, globalWalletLimit);
    }

    /// @notice Withdraws the contract's balance
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

    /// @notice Allows the owner to mint tokens
    /// @param to The address to mint tokens to
    /// @param tokenId The ID of the token to mint
    /// @param qty The quantity of tokens to mint
    function ownerMint(address to, uint256 tokenId, uint32 qty) external onlyOwner hasSupply(tokenId, qty) {
        _mint(to, tokenId, qty, "");
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
    /// @param cosigner The new cosigner address
    function setCosigner(address cosigner) external override onlyOwner {
        _setCosigner(cosigner);
    }

    /// @notice Sets the expiry time for timestamps
    /// @param timestampExpirySeconds The number of seconds after which a timestamp is considered expired
    function setTimestampExpirySeconds(uint256 timestampExpirySeconds) external override onlyOwner {
        _setTimestampExpirySeconds(timestampExpirySeconds);
    }

    /*==============================================================
    =                      INTERNAL HELPERS                        =
    ==============================================================*/

    /// @dev Internal function to handle minting logic
    /// @param to The address to mint tokens for
    /// @param tokenId The ID of the token to mint
    /// @param qty The quantity to mint
    /// @param limit The minting limit for the recipient (used in merkle proofs)
    /// @param proof The merkle proof for allowlist minting
    /// @param timestamp The timestamp for the minting action (used in cosigning)
    /// @param signature The cosigner's signature
    function _mintInternal(
        address to,
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint256 timestamp,
        bytes memory signature
    ) internal hasSupply(tokenId, qty) {
        uint256 stageTimestamp = block.timestamp;
        bool waiveMintFee = false;

        if (getCosigner() != address(0)) {
            waiveMintFee = assertValidCosign(msg.sender, qty, timestamp, signature, getCosignNonce(msg.sender, tokenId));
            _assertValidTimestamp(timestamp);
            stageTimestamp = timestamp;
        }

        uint256 activeStage = getActiveStageFromTimestamp(stageTimestamp);

        MintStageInfo1155 memory stage = _mintStages[activeStage];
        uint80 adjustedMintFee = waiveMintFee ? 0 : stage.mintFee[tokenId];

        // Check value if minting with ETH
        if (_mintCurrency == address(0) && msg.value < (stage.price[tokenId] + adjustedMintFee) * qty) {
            revert NotEnoughValue();
        }

        // Check stage supply if applicable
        if (stage.maxStageSupply[tokenId] > 0) {
            if (_stageMintedCountsPerToken[activeStage][tokenId] + qty > stage.maxStageSupply[tokenId]) {
                revert StageSupplyExceeded();
            }
        }

        // Check global wallet limit if applicable
        if (_globalWalletLimit[tokenId] > 0) {
            if (_totalMintedByTokenByAddress(to, tokenId) + qty > _globalWalletLimit[tokenId]) {
                revert WalletGlobalLimitExceeded();
            }
        }

        // Check wallet limit for stage if applicable, limit == 0 means no limit enforced
        if (stage.walletLimit[tokenId] > 0) {
            if (_stageMintedCountsPerTokenPerWallet[activeStage][tokenId][to] + qty > stage.walletLimit[tokenId]) {
                revert WalletStageLimitExceeded();
            }
        }

        // Check merkle proof if applicable, merkleRoot == 0x00...00 means no proof required
        if (stage.merkleRoot[tokenId] != 0) {
            if (!MerkleProofLib.verify(proof, stage.merkleRoot[tokenId], keccak256(abi.encodePacked(to, limit)))) {
                revert InvalidProof();
            }

            // Verify merkle proof mint limit
            if (limit > 0 && _stageMintedCountsPerTokenPerWallet[activeStage][tokenId][to] + qty > limit) {
                revert WalletStageLimitExceeded();
            }
        }

        if (_mintCurrency != address(0)) {
            // ERC20 mint payment
            SafeTransferLib.safeTransferFrom(
                _mintCurrency, msg.sender, address(this), (stage.price[tokenId] + adjustedMintFee) * qty
            );
        }

        _totalMintFee += adjustedMintFee * qty;
        _stageMintedCountsPerTokenPerWallet[activeStage][tokenId][to] += qty;
        _stageMintedCountsPerToken[activeStage][tokenId] += qty;
        _mint(to, tokenId, qty, "");
    }

    /// @dev Calculates the total minted tokens for a specific address and token ID
    /// @param account The address to check
    /// @param tokenId The ID of the token
    /// @return The total number of tokens minted for the given address and token ID
    function _totalMintedByTokenByAddress(address account, uint256 tokenId) internal view virtual returns (uint256) {
        uint256 totalMinted = 0;
        uint256 numStages = _mintStages.length;
        for (uint256 i = 0; i < numStages; i++) {
            totalMinted += _stageMintedCountsPerTokenPerWallet[i][tokenId][account];
        }
        return totalMinted;
    }

    /// @dev Calculates the total minted tokens for a specific address in a given stage
    /// @param stage The stage number
    /// @param account The address to check
    /// @return An array of total minted tokens for each token ID in the given stage
    function _totalMintedByStageByAddress(uint256 stage, address account)
        internal
        view
        virtual
        returns (uint256[] memory)
    {
        uint256[] memory totalMinted = new uint256[](_numTokens);
        for (uint256 token = 0; token < _numTokens; token++) {
            totalMinted[token] += _stageMintedCountsPerTokenPerWallet[stage][token][account];
        }
        return totalMinted;
    }

    /// @dev Validates the start and end timestamps for a stage
    /// @param start The start timestamp
    /// @param end The end timestamp
    function _assertValidStartAndEndTimestamp(uint256 start, uint256 end) internal pure {
        if (start >= end) revert InvalidStartAndEndTimestamp();
    }

    /// @dev Validates the length of stage arguments
    /// @param stageInfo The stage information to validate
    function _assertValidStageArgsLength(MintStageInfo1155 calldata stageInfo) internal view {
        if (
            stageInfo.price.length != _numTokens || stageInfo.mintFee.length != _numTokens
                || stageInfo.walletLimit.length != _numTokens || stageInfo.merkleRoot.length != _numTokens
                || stageInfo.maxStageSupply.length != _numTokens
        ) {
            revert InvalidStageArgsLength();
        }
    }

    /// @dev Overrides the _beforeTokenTransfer function to add custom logic
    /// @param operator The address performing the transfer
    /// @param from The address transferring the tokens
    /// @param to The address receiving the tokens
    /// @param ids The IDs of the tokens being transferred
    /// @param amounts The quantities of the tokens being transferred
    /// @param data Additional data with no specified format
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        // If the transfer is not from a mint or burn, revert if not transferable
        if (from != address(0) && to != address(0) && !_transferable) {
            revert NotTransferable();
        }

        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /// @dev Overriden to prevent double-initialization of the owner.
    function _guardInitializeOwner() internal pure virtual override returns (bool) {
        return true;
    }
}
