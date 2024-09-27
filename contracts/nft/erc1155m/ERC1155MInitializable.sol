//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC1155SupplyUpgradeable, ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import {MintStageInfo1155} from "../../common/Structs.sol";
import {IERC1155M} from "./interfaces/IERC1155M.sol";
import {MINT_FEE_RECEIVER} from "../../utils/Constants.sol";


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
    OwnableUpgradeable,
    ReentrancyGuard,
    ERC2981
{
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    // Mint stage information. See MintStageInfo for details.
    MintStageInfo1155[] private _mintStages;

    string public name;
    string public symbol;
    bool private _transferable; // Whether the token can be transferred.
    uint256[] private _maxMintableSupply; // The total mintable supply per token.
    uint256[] private _globalWalletLimit; // Global wallet limit, across all stages, per token.
    uint256 private _totalMintFee;
    uint64 private immutable _timestampExpirySeconds = 300;
    address private _cosigner; // The address of the cosigner server.
    address private _mintCurrency; // If 0 address, use native currency.
    uint256 private _numTokens;
    address private _fundReceiver;

    mapping(uint256 => mapping(uint256 => mapping(address => uint32)))
        private _stageMintedCountsPerTokenPerWallet;
    mapping(uint256 => mapping(uint256 => uint256))
        private _stageMintedCountsPerToken;
    mapping(address => bool) private _authorizedMinters;

    function initialize(
        string calldata name_,
        string calldata symbol_,
        address initialOwner
    ) external initializer {
        name = name_;
        symbol = symbol_;
        __ERC1155_init("");
        __Ownable_init(initialOwner);
    }


    function setup(
        string calldata uri_,
        uint256[] memory maxMintableSupply,
        uint256[] memory globalWalletLimit,
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
            if (
                maxMintableSupply[i] > 0 &&
                globalWalletLimit[i] > maxMintableSupply[i]
            ) {
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

        _setURI(uri_);
        setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    /**
     * @dev Returns whether it has enough supply for the given qty.
     */
    modifier hasSupply(uint256 tokenId, uint256 qty) {
        if (
            _maxMintableSupply[tokenId] > 0 &&
            totalSupply(tokenId) + qty > _maxMintableSupply[tokenId]
        ) revert NoSupplyLeft();
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
     * @dev Returns cosign nonce.
     */
    function getCosignNonce(
        address minter,
        uint256 tokenId
    ) public view returns (uint256) {
        return totalMintedByAddress(minter)[tokenId];
    }

    /**
     * @dev Sets cosigner.
     */
    function setCosigner(address cosigner) external onlyOwner {
        _cosigner = cosigner;
        emit SetCosigner(cosigner);
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
    function setStages(MintStageInfo1155[] calldata newStages) external onlyOwner {
        delete _mintStages;

        for (uint256 i = 0; i < newStages.length; i++) {
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
    function getMaxMintableSupply(
        uint256 tokenId
    ) external view override returns (uint256) {
        return _maxMintableSupply[tokenId];
    }

    /**
     * @dev Sets maximum mintable supply. New supply cannot be larger than the old or the supply alraedy minted.
     */
    function setMaxMintableSupply(
        uint256 tokenId,
        uint256 maxMintableSupply
    ) external virtual onlyOwner {
        if (tokenId >= _numTokens) {
            revert InvalidTokenId();
        }
        if (
            _maxMintableSupply[tokenId] != 0 &&
            maxMintableSupply > _maxMintableSupply[tokenId]
        ) {
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
    function getGlobalWalletLimit(
        uint256 tokenId
    ) external view override returns (uint256) {
        return _globalWalletLimit[tokenId];
    }

    /**
     * @dev Sets global wallet limit.
     */
    function setGlobalWalletLimit(
        uint256 tokenId,
        uint256 globalWalletLimit
    ) external onlyOwner {
        if (tokenId >= _numTokens) {
            revert InvalidTokenId();
        }
        if (
            _maxMintableSupply[tokenId] > 0 &&
            globalWalletLimit > _maxMintableSupply[tokenId]
        ) {
            revert GlobalWalletLimitOverflow();
        }
        _globalWalletLimit[tokenId] = globalWalletLimit;
        emit SetGlobalWalletLimit(tokenId, globalWalletLimit);
    }

    /**
     * @dev Returns number of minted tokens for a given address.
     */
    function totalMintedByAddress(
        address account
    ) public view virtual override returns (uint256[] memory) {
        uint256[] memory totalMinted = new uint256[](_numTokens);
        uint256 numStages = _mintStages.length;
        for (uint256 token = 0; token < _numTokens; token++) {
            for (uint256 stage = 0; stage < numStages; stage++) {
                totalMinted[token] += _stageMintedCountsPerTokenPerWallet[
                    stage
                ][token][account];
            }
        }
        return totalMinted;
    }

    /**
     * @dev Returns number of minted token for a given token and address.
     */
    function _totalMintedByTokenByAddress(
        address account,
        uint256 tokenId
    ) internal view virtual returns (uint256) {
        uint256 totalMinted = 0;
        uint256 numStages = _mintStages.length;
        for (uint256 i = 0; i < numStages; i++) {
            totalMinted += _stageMintedCountsPerTokenPerWallet[i][tokenId][
                account
            ];
        }
        return totalMinted;
    }

    /**
     * @dev Returns number of minted tokens for a given stage and address.
     */
    function _totalMintedByStageByAddress(
        uint256 stage,
        address account
    ) internal view virtual returns (uint256[] memory) {
        uint256[] memory totalMinted = new uint256[](_numTokens);
        for (uint256 token = 0; token < _numTokens; token++) {
            totalMinted[token] += _stageMintedCountsPerTokenPerWallet[stage][
                token
            ][account];
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
    function getStageInfo(
        uint256 stage
    )
        external
        view
        override
        returns (MintStageInfo1155 memory, uint256[] memory, uint256[] memory)
    {
        if (stage >= _mintStages.length) {
            revert InvalidStage();
        }
        uint256[] memory walletMinted = totalMintedByAddress(msg.sender);
        uint256[] memory stageMinted = _totalMintedByStageByAddress(
            stage,
            msg.sender
        );
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
    function mint(
        uint256 tokenId,
        uint32 qty,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable virtual nonReentrant {
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
        _mintInternal(
            msg.sender,
            tokenId,
            qty,
            limit,
            proof,
            timestamp,
            signature
        );
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
    function authorizedMint(
        address to,
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof
    ) external payable onlyAuthorizedMinter {
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
            waiveMintFee = assertValidCosign(
                msg.sender,
                tokenId,
                qty,
                timestamp,
                signature
            );
            _assertValidTimestamp(timestamp);
            stageTimestamp = timestamp;
        }

        uint256 activeStage = getActiveStageFromTimestamp(stageTimestamp);

        MintStageInfo1155 memory stage = _mintStages[activeStage];
        uint80 adjustedMintFee = waiveMintFee ? 0 : stage.mintFee[tokenId];

        // Check value if minting with ETH
        if (
            _mintCurrency == address(0) &&
            msg.value < (stage.price[tokenId] + adjustedMintFee) * qty
        ) revert NotEnoughValue();

        // Check stage supply if applicable
        if (stage.maxStageSupply[tokenId] > 0) {
            if (
                _stageMintedCountsPerToken[activeStage][tokenId] + qty >
                stage.maxStageSupply[tokenId]
            ) revert StageSupplyExceeded();
        }

        // Check global wallet limit if applicable
        if (_globalWalletLimit[tokenId] > 0) {
            if (
                _totalMintedByTokenByAddress(to, tokenId) + qty >
                _globalWalletLimit[tokenId]
            ) revert WalletGlobalLimitExceeded();
        }

        // Check wallet limit for stage if applicable, limit == 0 means no limit enforced
        if (stage.walletLimit[tokenId] > 0) {
            if (
                _stageMintedCountsPerTokenPerWallet[activeStage][tokenId][to] +
                    qty >
                stage.walletLimit[tokenId]
            ) revert WalletStageLimitExceeded();
        }

        // Check merkle proof if applicable, merkleRoot == 0x00...00 means no proof required
        if (stage.merkleRoot[tokenId] != 0) {
            if (
                MerkleProof.processProof(
                    proof,
                    keccak256(abi.encodePacked(to, limit))
                ) != stage.merkleRoot[tokenId]
            ) revert InvalidProof();

            // Verify merkle proof mint limit
            if (
                limit > 0 &&
                _stageMintedCountsPerTokenPerWallet[activeStage][tokenId][to] +
                    qty >
                limit
            ) {
                revert WalletStageLimitExceeded();
            }
        }

        if (_mintCurrency != address(0)) {
            // ERC20 mint payment
            IERC20(_mintCurrency).safeTransferFrom(
                msg.sender,
                address(this),
                (stage.price[tokenId] + adjustedMintFee) * qty
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
    function ownerMint(
        address to,
        uint256 tokenId,
        uint32 qty
    ) external onlyOwner hasSupply(tokenId, qty) {
        _mint(to, tokenId, qty, "");
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
    function getActiveStageFromTimestamp(
        uint64 timestamp
    ) public view returns (uint256) {
        for (uint256 i = 0; i < _mintStages.length; i++) {
            if (
                timestamp >= _mintStages[i].startTimeUnixSeconds &&
                timestamp < _mintStages[i].endTimeUnixSeconds
            ) {
                return i;
            }
        }
        revert InvalidStage();
    }

    /**
     * @dev Returns data hash for the given minter, qty, waiveMintFee and timestamp.
     */
    function getCosignDigest(
        address minter,
        uint256 tokenId,
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
                        block.chainid,
                        getCosignNonce(minter, tokenId)
                    )
                )
            );
    }

    /**
     * @dev Validates the the given signature. Returns whether mint fee is waived.
     */
    function assertValidCosign(
        address minter,
        uint256 tokenId,
        uint32 qty,
        uint64 timestamp,
        bytes memory signature
    ) public view returns (bool) {
        if (
            SignatureChecker.isValidSignatureNow(
                _cosigner,
                getCosignDigest(
                    minter,
                    tokenId,
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
                    tokenId,
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

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC2981, ERC1155Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId) ||
            ERC1155Upgradeable.supportsInterface(interfaceId);
    }

    /**
     * @dev The hook of token transfer to validate the transfer.
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        super._update(from, to, ids, values);

        bool fromZeroAddress = from == address(0);
        bool toZeroAddress = to == address(0);

        if (!fromZeroAddress && !toZeroAddress && !_transferable) {
            revert NotTransferable();
        }
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
     * @dev Validates the timestamp is not expired.
     */
    function _assertValidTimestamp(uint64 timestamp) internal view {
        if (timestamp < block.timestamp - _timestampExpirySeconds)
            revert TimestampExpired();
    }

    function _assertValidStageArgsLength(
        MintStageInfo1155 calldata stageInfo
    ) internal view {
        if (
            stageInfo.price.length != _numTokens ||
            stageInfo.mintFee.length != _numTokens ||
            stageInfo.walletLimit.length != _numTokens ||
            stageInfo.merkleRoot.length != _numTokens ||
            stageInfo.maxStageSupply.length != _numTokens
        ) {
            revert InvalidStageArgsLength();
        }
    }

    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) public onlyOwner {
        super._setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) public onlyOwner {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit TokenRoyaltySet(tokenId, receiver, feeNumerator);
    }
}
