//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

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
import {IERC1155M} from "./interfaces/IERC1155M.sol";
import {MINT_FEE_RECEIVER} from "../../utils/Constants.sol";
import {ERC1155MStorage} from "./ERC1155MStorage.sol";
import {Cosignable} from "../../common/Cosignable.sol";
import {AuthorizedMinterControl} from "../../common/AuthorizedMinterControl.sol";

/**
 * @title ERC1155MInitializable
 *
 * @dev OpenZeppelin's ERC1155 subclass with MagicEden launchpad features including
 *  - multi token minting
 *  - multi minting stages with time-based auto stage switch
 *  - global and stage wallet-level minting limit
 *  - whitelist
 *  - variable wallet limit
 */
contract ERC1155MInitializable is
    IERC1155M,
    ERC1155SupplyUpgradeable,
    Ownable,
    ReentrancyGuard,
    ERC1155MStorage,
    ERC2981,
    Cosignable,
    AuthorizedMinterControl
{
    constructor() {
        _disableInitializers();
    }

    function initialize(string calldata name_, string calldata symbol_, address initialOwner) external initializer {
        name = name_;
        symbol = symbol_;
        __ERC1155_init("");
        _initializeOwner(initialOwner);
    }

    function setup(
        string calldata uri_,
        uint256[] memory maxMintableSupply,
        uint256[] memory globalWalletLimit,
        uint64 timestampExpirySeconds,
        address cosigner,
        address mintCurrency,
        address fundReceiver,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external onlyOwner {
        if (maxMintableSupply.length != globalWalletLimit.length) {
            revert InvalidLimitArgsLength();
        }

        for (uint256 i = 0; i < globalWalletLimit.length; i++) {
            if (maxMintableSupply[i] > 0 && globalWalletLimit[i] > maxMintableSupply[i]) {
                revert GlobalWalletLimitOverflow();
            }
        }

        _numTokens = globalWalletLimit.length;
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
        _cosigner = cosigner;
        _transferable = true;
        _mintCurrency = mintCurrency;
        _fundReceiver = fundReceiver;
        _timestampExpirySeconds = timestampExpirySeconds;

        _setURI(uri_);
        setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    /**
     * @dev Returns whether it has enough supply for the given qty.
     */
    modifier hasSupply(uint256 tokenId, uint256 qty) {
        if (_maxMintableSupply[tokenId] > 0 && totalSupply(tokenId) + qty > _maxMintableSupply[tokenId]) {
            revert NoSupplyLeft();
        }
        _;
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
        _cosigner = cosigner;
        emit SetCosigner(cosigner);
    }

    /**
     * @dev Returns cosign nonce.
     */
    function getCosignNonce(address minter, uint256 tokenId) public view returns (uint256) {
        return totalMintedByAddress(minter)[tokenId];
    }

    /**
     * @dev Sets stages in the format of an array of `MintStageInfo`.
     */
    function setStages(MintStageInfo1155[] calldata newStages) external onlyOwner {
        delete _mintStages;

        for (uint256 i = 0; i < newStages.length; i++) {
            if (i >= 1) {
                if (newStages[i].startTimeUnixSeconds < newStages[i - 1].endTimeUnixSeconds + _timestampExpirySeconds) {
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

    /**
     * @dev Returns maximum mintable supply per token.
     */
    function getMaxMintableSupply(uint256 tokenId) external view override returns (uint256) {
        return _maxMintableSupply[tokenId];
    }

    /**
     * @dev Sets maximum mintable supply. New supply cannot be larger than the old or the supply alraedy minted.
     */
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

    /**
     * @dev Returns global wallet limit. This is the max number of tokens can be minted by one wallet.
     */
    function getGlobalWalletLimit(uint256 tokenId) external view override returns (uint256) {
        return _globalWalletLimit[tokenId];
    }

    /**
     * @dev Sets global wallet limit.
     */
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

    /**
     * @dev Returns number of minted tokens for a given address.
     */
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

    /**
     * @dev Returns number of minted token for a given token and address.
     */
    function _totalMintedByTokenByAddress(address account, uint256 tokenId) internal view virtual returns (uint256) {
        uint256 totalMinted = 0;
        uint256 numStages = _mintStages.length;
        for (uint256 i = 0; i < numStages; i++) {
            totalMinted += _stageMintedCountsPerTokenPerWallet[i][tokenId][account];
        }
        return totalMinted;
    }

    /**
     * @dev Returns number of minted tokens for a given stage and address.
     */
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

    /**
     * @dev Returns number of stages.
     */
    function getNumberStages() external view override returns (uint256) {
        return _mintStages.length;
    }

    /**
     * @dev Returns info for one stage specified by stage index (starting from 0).
     */
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

    /**
     * @dev Returns mint currency address.
     */
    function getMintCurrency() external view returns (address) {
        return _mintCurrency;
    }

    /**
     * @dev Mints token(s).
     *
     * tokenId - token id
     * qty - number of tokens to mint
     * proof - the merkle proof generated on client side. This applies if using whitelist
     * timestamp - the current timestamp
     * signature - the signature from cosigner if using cosigner
     */
    function mint(uint256 tokenId, uint32 qty, bytes32[] calldata proof, uint64 timestamp, bytes calldata signature)
        external
        payable
        virtual
        nonReentrant
    {
        _mintInternal(msg.sender, tokenId, qty, 0, proof, timestamp, signature);
    }

    /**
     * @dev Mints token(s) with limit.
     *
     * tokenId - token id
     * qty - number of tokens to mint
     * limit - limit for the given minter
     * proof - the merkle proof generated on client side. This applies if using whitelist
     * timestamp - the current timestamp
     * signature - the signature from cosigner if using cosigner
     */
    function mintWithLimit(
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable virtual nonReentrant {
        _mintInternal(msg.sender, tokenId, qty, limit, proof, timestamp, signature);
    }

    /**
     * @dev Authorized mints token(s) with limit
     *
     * to - the token recipient
     * tokenId - token id
     * qty - number of tokens to mint
     * limit - limit for the given minter
     * proof - the merkle proof generated on client side. This applies if using whitelist
     */
    function authorizedMint(address to, uint256 tokenId, uint32 qty, uint32 limit, bytes32[] calldata proof)
        external
        payable
        onlyAuthorizedMinter
    {
        _mintInternal(to, tokenId, qty, limit, proof, 0, bytes("0"));
    }

    /**
     * @dev Implementation of minting.
     */
    function _mintInternal(
        address to,
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes memory signature
    ) internal hasSupply(tokenId, qty) {
        uint64 stageTimestamp = uint64(block.timestamp);
        bool waiveMintFee = false;

        if (_cosigner != address(0)) {
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

    /**
     * @dev Mints token(s) by owner.
     *
     * NOTE: This function bypasses validations thus only available for owner.
     * This is typically used for owner to  pre-mint or mint the remaining of the supply.
     */
    function ownerMint(address to, uint256 tokenId, uint32 qty) external onlyOwner hasSupply(tokenId, qty) {
        _mint(to, tokenId, qty, "");
    }

    /**
     * @dev Withdraws funds by owner.
     */
    function withdraw() external onlyOwner {
        (bool success,) = MINT_FEE_RECEIVER.call{value: _totalMintFee}("");
        if (!success) revert TransferFailed();
        _totalMintFee = 0;

        uint256 remainingValue = address(this).balance;
        (success,) = _fundReceiver.call{value: remainingValue}("");
        if (!success) revert WithdrawFailed();

        emit Withdraw(_totalMintFee + remainingValue);
    }

    /**
     * @dev Withdraws ERC-20 funds by owner.
     */
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

    /**
     * @dev Sets a new URI for all token types. The URI relies on token type ID
     * substitution mechanism.
     */
    function setURI(string calldata newURI) external onlyOwner {
        _setURI(newURI);
    }

    /**
     * @dev Sets transferable of the tokens.
     */
    function setTransferable(bool transferable) external onlyOwner {
        _transferable = transferable;
        emit SetTransferable(transferable);
    }

    /**
     * @dev Returns the current active stage based on timestamp.
     */
    function getActiveStageFromTimestamp(uint64 timestamp) public view returns (uint256) {
        for (uint256 i = 0; i < _mintStages.length; i++) {
            if (timestamp >= _mintStages[i].startTimeUnixSeconds && timestamp < _mintStages[i].endTimeUnixSeconds) {
                return i;
            }
        }
        revert InvalidStage();
    }

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

    /**
     * @dev Validates the start timestamp is before end timestamp. Used when updating stages.
     */
    function _assertValidStartAndEndTimestamp(uint64 start, uint64 end) internal pure {
        if (start >= end) revert InvalidStartAndEndTimestamp();
    }

    function _assertValidStageArgsLength(MintStageInfo1155 calldata stageInfo) internal view {
        if (
            stageInfo.price.length != _numTokens || stageInfo.mintFee.length != _numTokens
                || stageInfo.walletLimit.length != _numTokens || stageInfo.merkleRoot.length != _numTokens
                || stageInfo.maxStageSupply.length != _numTokens
        ) {
            revert InvalidStageArgsLength();
        }
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) public onlyOwner {
        super._setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) public onlyOwner {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit TokenRoyaltySet(tokenId, receiver, feeNumerator);
    }
}
