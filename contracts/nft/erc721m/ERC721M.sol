//SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

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
import {LAUNCHPAD_MINT_FEE_RECEIVER} from "../../utils/Constants.sol";

/// @title ERC721M
/// @notice An initializable ERC721 contract with multi-stage minting, royalties, and authorized minters
/// @dev Implements ERC721, Ownable, ReentrancyGuard, and custom minting logic
contract ERC721M is
    IERC721M,
    ERC721AQueryable,
    Ownable,
    ReentrancyGuard,
    Cosignable,
    AuthorizedMinterControl,
    ERC721MStorage
{
    /*==============================================================
    =                          CONSTRUCTOR                        =
    ==============================================================*/

    /// @notice Constructor for the ERC721M contract
    /// @param collectionName The name of the collection
    /// @param collectionSymbol The symbol of the collection
    /// @param tokenURISuffix The suffix for the token URI
    /// @param maxMintableSupply The maximum number of tokens that can be minted
    /// @param globalWalletLimit The global wallet limit for minting
    /// @param cosigner The address of the cosigner
    /// @param timestampExpirySeconds The expiry time in seconds for timestamps
    /// @param mintCurrency The address of the mint currency
    /// @param fundReceiver The address of the fund receiver
    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint256 timestampExpirySeconds,
        address mintCurrency,
        address fundReceiver,
        uint256 mintFee
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
        _mintFee = mintFee;

        _initializeOwner(msg.sender);
        _setCosigner(cosigner);
        _setTimestampExpirySeconds(timestampExpirySeconds);
    }

    /*==============================================================
    =                             META                             =
    ==============================================================*/

    /// @notice Returns the contract name and version
    /// @return The contract name and version as strings
    function contractNameAndVersion() public pure returns (string memory, string memory) {
        return ("ERC721M", "1.0.0");
    }

    /// @notice Gets the token URI for a specific token ID
    /// @param tokenId The ID of the token
    /// @return The token URI
    function tokenURI(uint256 tokenId) public view override(ERC721A, IERC721A) returns (string memory) {
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

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Gets the stage info for a given stage index
    /// @param index The stage index
    /// @return The stage info, wallet minted count, and stage minted count
    function getStageInfo(uint256 index) external view override returns (MintStageInfo memory, uint32, uint256) {
        if (index >= _mintStages.length) {
            revert("InvalidStage");
        }
        uint32 walletMinted = _stageMintedCountsPerWallet[index][msg.sender];
        uint256 stageMinted = _stageMintedCounts[index];
        return (_mintStages[index], walletMinted, stageMinted);
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

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

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
        }
    }

    /// @notice Sets the mintable status
    /// @param mintable The mintable status to set
    function setMintable(bool mintable) external onlyOwner {
        _mintable = mintable;
        emit SetMintable(mintable);
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
        (bool success,) = LAUNCHPAD_MINT_FEE_RECEIVER.call{value: _totalMintFee}("");
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

        SafeTransferLib.safeTransfer(_mintCurrency, LAUNCHPAD_MINT_FEE_RECEIVER, totalFee);
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

    /// @notice Validates the start and end timestamps for a stage
    /// @param start The start timestamp
    /// @param end The end timestamp
    function _assertValidStartAndEndTimestamp(uint256 start, uint256 end) internal pure {
        if (start >= end) revert InvalidStartAndEndTimestamp();
    }

    /// @dev Overriden to prevent double-initialization of the owner.
    function _guardInitializeOwner() internal pure virtual override returns (bool) {
        return true;
    }
}
