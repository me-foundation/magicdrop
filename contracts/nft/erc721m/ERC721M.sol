//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {ERC721AQueryable, IERC721A, ERC721A} from "erc721a/contracts/extensions/ERC721AQueryable.sol";

import {IERC721M} from "./interfaces/IERC721M.sol";
import {ERC721MStorage} from "./ERC721MStorage.sol";

import {Cosignable} from "../../common/Cosignable.sol";
import {AuthorizedMinterControl} from "../../common/AuthorizedMinterControl.sol";
import {MintStageInfo} from "../../common/Structs.sol";
import {MINT_FEE_RECEIVER} from "../../utils/Constants.sol";

contract ERC721M is
    IERC721M,
    ERC721AQueryable,
    Ownable,
    ReentrancyGuard,
    Cosignable,
    AuthorizedMinterControl,
    ERC721MStorage
{
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
    ) ERC721A(collectionName, collectionSymbol) {
        if (globalWalletLimit > maxMintableSupply) {
            revert GlobalWalletLimitOverflow();
        }
        _mintable = true;
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
        _tokenURISuffix = tokenURISuffix;
        _mintCurrency = mintCurrency;
        _fundReceiver = fundReceiver;

        _setCosigner(cosigner);
        _setTimestampExpirySeconds(timestampExpirySeconds);
        _initializeOwner(msg.sender);
    }

    modifier canMint() {
        if (!_mintable) revert NotMintable();
        _;
    }

    modifier hasSupply(uint256 qty) {
        if (totalSupply() + qty > _maxMintableSupply) revert NoSupplyLeft();
        _;
    }

    function getCosignNonce(address minter) public view returns (uint256) {
        return _numberMinted(minter);
    }

    function addAuthorizedMinter(address minter) external override onlyOwner {
        _addAuthorizedMinter(minter);
    }

    function removeAuthorizedMinter(address minter) external override onlyOwner {
        _removeAuthorizedMinter(minter);
    }

    function setCosigner(address cosigner) external override onlyOwner {
        _setCosigner(cosigner);
    }

    function setTimestampExpirySeconds(uint256 timestampExpirySeconds) external override onlyOwner {
        _setTimestampExpirySeconds(timestampExpirySeconds);
    }

    function setStages(MintStageInfo[] calldata newStages) external onlyOwner {
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
        }
    }

    function getMintable() external view returns (bool) {
        return _mintable;
    }

    function setMintable(bool mintable) external onlyOwner {
        _mintable = mintable;
        emit SetMintable(mintable);
    }

    function getNumberStages() external view override returns (uint256) {
        return _mintStages.length;
    }

    function getMaxMintableSupply() external view override returns (uint256) {
        return _maxMintableSupply;
    }

    function setMaxMintableSupply(uint256 maxMintableSupply) external virtual onlyOwner {
        if (maxMintableSupply > _maxMintableSupply) {
            revert CannotIncreaseMaxMintableSupply();
        }
        _maxMintableSupply = maxMintableSupply;
        emit SetMaxMintableSupply(maxMintableSupply);
    }

    function getGlobalWalletLimit() external view override returns (uint256) {
        return _globalWalletLimit;
    }

    function setGlobalWalletLimit(uint256 globalWalletLimit) external onlyOwner {
        if (globalWalletLimit > _maxMintableSupply) {
            revert GlobalWalletLimitOverflow();
        }
        _globalWalletLimit = globalWalletLimit;
        emit SetGlobalWalletLimit(globalWalletLimit);
    }

    function totalMintedByAddress(address a) external view virtual override returns (uint256) {
        return _numberMinted(a);
    }

    function getStageInfo(uint256 index) external view override returns (MintStageInfo memory, uint32, uint256) {
        if (index >= _mintStages.length) {
            revert("InvalidStage");
        }
        uint32 walletMinted = _stageMintedCountsPerWallet[index][msg.sender];
        uint256 stageMinted = _stageMintedCounts[index];
        return (_mintStages[index], walletMinted, stageMinted);
    }

    function getMintCurrency() external view returns (address) {
        return _mintCurrency;
    }

    function mint(uint32 qty, uint32 limit, bytes32[] calldata proof, uint256 timestamp, bytes calldata signature)
        external
        payable
        virtual
        nonReentrant
    {
        _mintInternal(qty, msg.sender, limit, proof, timestamp, signature);
    }

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

    function ownerMint(uint32 qty, address to) external onlyOwner hasSupply(qty) {
        _safeMint(to, qty);
    }

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

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _currentBaseURI = baseURI;
        emit SetBaseURI(baseURI);
    }

    function setTokenURISuffix(string calldata suffix) external onlyOwner {
        _tokenURISuffix = suffix;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _currentBaseURI;
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId), _tokenURISuffix)) : "";
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function setContractURI(string calldata uri) external onlyOwner {
        _contractURI = uri;
        emit SetContractURI(uri);
    }

    function getActiveStageFromTimestamp(uint256 timestamp) public view returns (uint256) {
        for (uint256 i = 0; i < _mintStages.length; i++) {
            if (timestamp >= _mintStages[i].startTimeUnixSeconds && timestamp < _mintStages[i].endTimeUnixSeconds) {
                return i;
            }
        }
        revert InvalidStage();
    }

    function _assertValidStartAndEndTimestamp(uint256 start, uint256 end) internal pure {
        if (start >= end) revert InvalidStartAndEndTimestamp();
    }

    function _chainID() private view returns (uint256) {
        uint256 chainID;
        /// @solidity memory-safe-assembly
        assembly {
            chainID := chainid()
        }
        return chainID;
    }
}
