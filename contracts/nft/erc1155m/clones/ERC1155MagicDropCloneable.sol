// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

import {ERC1155MagicDropMetadataCloneable} from "./ERC1155MagicDropMetadataCloneable.sol";
import {ERC1155ConduitPreapprovedCloneable} from "./ERC1155ConduitPreapprovedCloneable.sol";
import {PublicStage, AllowlistStage, SetupConfig} from "./Types.sol";
import {IERC1155MagicDropMetadata} from "../interfaces/IERC1155MagicDropMetadata.sol";

import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";

contract ERC1155MagicDropCloneable is ERC1155MagicDropMetadataCloneable, ReentrancyGuard {
    /// @dev Address that receives the primary sale proceeds of minted tokens.
    ///      Configurable by the owner. If unset, withdrawals may fail.
    address internal _payoutRecipient;

    /// @dev Configuration of the public mint stage, including timing and price.
    /// @notice Public mints occur only if the current timestamp is within [startTime, endTime].
    mapping(uint256 => PublicStage) internal _publicStages; // tokenId => publicStage

    /// @dev Configuration of the allowlist mint stage, including timing, price, and a merkle root for verification.
    /// @notice Only addresses proven by a valid Merkle proof can mint during this stage.
    mapping(uint256 => AllowlistStage) internal _allowlistStages; // tokenId => allowlistStage

    /// @notice Thrown when attempting to mint during a public stage that is not currently active.
    error PublicStageNotActive();

    /// @notice Thrown when attempting to mint during an allowlist stage that is not currently active.
    error AllowlistStageNotActive();

    /// @notice Thrown when the provided ETH value for a mint is insufficient.
    error NotEnoughValue();

    /// @notice Thrown when the provided Merkle proof for an allowlist mint is invalid.
    error InvalidProof();

    /// @notice Thrown when a stage's start or end time configuration is invalid.
    error InvalidStageTime();

    /// @notice Thrown when the public stage timing conflicts with the allowlist stage timing.
    error InvalidPublicStageTime();

    /// @notice Thrown when the allowlist stage timing conflicts with the public stage timing.
    error InvalidAllowlistStageTime();

    /// @notice Thrown when the payout recipient is set to a zero address.
    error PayoutRecipientCannotBeZeroAddress();

    /*==============================================================
    =                     PUBLIC WRITE METHODS                     =
    ==============================================================*/

    function mintPublic(uint256 tokenId, uint256 qty, address to, bytes memory data) external payable nonReentrant {
        PublicStage memory stage = _publicStages[tokenId];
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert PublicStageNotActive();
        }

        uint256 requiredPayment = stage.price * qty;
        if (msg.value < requiredPayment) {
            revert NotEnoughValue();
        }

        if (_totalMintedByUserPerToken[to][tokenId] + qty > this.walletLimit(tokenId)) {
            revert WalletLimitExceeded(tokenId);
        }

        if (stage.price != 0) {
            _splitProceeds();
        }

        _mint(to, tokenId, qty, data);
    }

    function mintAllowlist(uint256 tokenId, uint256 qty, address to, bytes32[] calldata proof, bytes memory data) external payable nonReentrant {
        AllowlistStage memory stage = _allowlistStages[tokenId];
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert AllowlistStageNotActive();
        }

        if (!MerkleProofLib.verify(proof, stage.merkleRoot, keccak256(abi.encodePacked(to)))) {
            revert InvalidProof();
        }

        uint256 requiredPayment = stage.price * qty;
        if (msg.value < requiredPayment) {
            revert NotEnoughValue();
        }

        if (stage.price != 0) {
            _splitProceeds();
        }

        _increaseSupplyOnMint(to, tokenId, qty);
        _mint(to, tokenId, qty, data);
    }

    function burn(uint256 tokenId, uint256 qty, address from) external {
        _reduceSupplyOnBurn(tokenId, qty);
        _burn(from, tokenId, qty);
    }

    function burn(address by, address from, uint256 id, uint256 qty) external {
        _reduceSupplyOnBurn(id, qty);
        _burn(by, from, id, qty);
    }

    function burnBatch(address by, address from, uint256[] calldata ids, uint256[] calldata qty) external {
        uint256 length = ids.length;
        for (uint256 i = 0; i < length; i++) {
            _reduceSupplyOnBurn(ids[i], qty[i]);
            unchecked {
                ++i;
            }
        }

        _batchBurn(by, from, ids, qty);
    }

    /*==============================================================
    =                     PUBLIC VIEW METHODS                      =
    ==============================================================*/

    /// @notice Returns the current payout recipient who receives primary sales proceeds after protocol fees.
    /// @return The address currently set to receive payout funds.
    function payoutRecipient() external view returns (address) {
        return _payoutRecipient;
    }

    /// @notice Returns the current public stage configuration (startTime, endTime, price).
    /// @return The current public stage settings.
    function getPublicStage(uint256 tokenId) external view returns (PublicStage memory) {
        return _publicStages[tokenId];
    }

    /// @notice Returns the current allowlist stage configuration (startTime, endTime, price, merkleRoot).
    /// @return The current allowlist stage settings.
    function getAllowlistStage(uint256 tokenId) external view returns (AllowlistStage memory) {
        return _allowlistStages[tokenId];
    }

    /// @notice Indicates whether the contract implements a given interface.
    /// @param interfaceId The interface ID to check for support.
    /// @return True if the interface is supported, false otherwise.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155MagicDropMetadataCloneable)
        returns (bool)
    {
        return interfaceId == type(IERC1155MagicDropMetadata).interfaceId || super.supportsInterface(interfaceId);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    function setup(SetupConfig calldata config) external onlyOwner {
        if (config.maxSupply > 0) {
            _setMaxSupply(config.tokenId, config.maxSupply);
        }

        if (config.walletLimit > 0) {
            _setWalletLimit(config.tokenId, config.walletLimit);
        }

        if (bytes(config.baseURI).length > 0) {
            _setBaseURI(config.baseURI);
        }

        if (bytes(config.contractURI).length > 0) {
            _setContractURI(config.contractURI);
        }

        if (config.allowlistStage.startTime != 0 || config.allowlistStage.endTime != 0) {
            _setAllowlistStage(config.tokenId, config.allowlistStage);
        }

        if (config.publicStage.startTime != 0 || config.publicStage.endTime != 0) {
            _setPublicStage(config.tokenId, config.publicStage);
        }

        if (config.payoutRecipient != address(0)) {
            _setPayoutRecipient(config.payoutRecipient);
        }
    }

    function setPublicStage(uint256 tokenId, PublicStage calldata stage) external onlyOwner {
        if (stage.startTime >= stage.endTime) {
            revert InvalidStageTime();
        }

        // Ensure the public stage starts after the allowlist stage ends
        if (_allowlistStages[tokenId].startTime != 0 && _allowlistStages[tokenId].endTime != 0) {
            if (stage.startTime < _allowlistStages[tokenId].endTime) {
                revert InvalidPublicStageTime();
            }
        }

        _publicStages[tokenId] = stage;
    }

    function setAllowlistStage(uint256 tokenId, AllowlistStage calldata stage) external onlyOwner {
        _allowlistStages[tokenId] = stage;
    }

    function setPayoutRecipient(address newPayoutRecipient) external onlyOwner {
        _setPayoutRecipient(newPayoutRecipient);
    }

    /*==============================================================
    =                      INTERNAL HELPERS                        =
    ==============================================================*/

    function _splitProceeds() internal {}

    function _setPayoutRecipient(address newPayoutRecipient) internal {
        _payoutRecipient = newPayoutRecipient;
    }

    function _setPublicStage(uint256 tokenId, PublicStage calldata stage) internal {}

    function _setAllowlistStage(uint256 tokenId, AllowlistStage calldata stage) internal {}

    function _reduceSupplyOnBurn(uint256 tokenId, uint256 qty) internal {
        TokenSupply storage supply = _tokenSupply[tokenId];
        unchecked {
            supply.totalSupply -= uint64(qty);
        }
    }

    function _increaseSupplyOnMint(address to, uint256 tokenId, uint256 qty) internal {
        TokenSupply storage supply = _tokenSupply[tokenId];

        if (supply.totalMinted + qty > supply.maxSupply) {
            revert CannotExceedMaxSupply();
        }

        unchecked {
            supply.totalSupply += uint64(qty);
            supply.totalMinted += uint64(qty);

            _totalMintedByUserPerToken[to][tokenId] += uint64(qty);
        }
    }

    /*==============================================================
    =                             META                             =
    ==============================================================*/

    function contractNameAndVersion() public pure returns (string memory, string memory) {
        return ("ERC1155MagicDropCloneable", "1.0.0");
    }

    /*==============================================================
    =                             MISC                             =
    ==============================================================*/

    function _guardInitializeOwner() internal pure virtual override returns (bool) {
        return true;
    }
}
