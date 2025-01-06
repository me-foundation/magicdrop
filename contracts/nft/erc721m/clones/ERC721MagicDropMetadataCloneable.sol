// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

import {IERC721A} from "erc721a/contracts/IERC721A.sol";

import {ERC721AConduitPreapprovedCloneable} from "./ERC721AConduitPreapprovedCloneable.sol";
import {ERC721ACloneable} from "./ERC721ACloneable.sol";
import {ERC721AQueryableCloneable} from "./ERC721AQueryableCloneable.sol";
import {IERC721MagicDropMetadata} from "../interfaces/IERC721MagicDropMetadata.sol";

/// @title ERC721MagicDropMetadataCloneable
/// @notice A cloneable ERC-721A implementation that supports adjustable metadata URIs, royalty configuration.
///         Inherits conduit-based preapprovals, making distribution more gas-efficient.
contract ERC721MagicDropMetadataCloneable is
    ERC721AConduitPreapprovedCloneable,
    IERC721MagicDropMetadata,
    ERC2981,
    Ownable
{
    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @notice Initializes the contract.
    /// @dev This function is called by the initializer of the parent contract.
    /// @param owner The address of the contract owner.
    function __ERC721MagicDropMetadataCloneable__init(address owner) internal onlyInitializing {
        _initializeOwner(owner);

        emit MagicDropTokenDeployed();
    }

    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    /// @notice The base URI used to construct `tokenURI` results.
    /// @dev This value can be updated by the contract owner. Typically points to an off-chain IPFS/HTTPS endpoint.
    string internal _tokenBaseURI;

    /// @notice A URI providing contract-level metadata (e.g., for marketplaces).
    /// @dev Can be updated by the owner. Often returns metadata in a JSON format describing the project.
    string internal _contractURI;

    /// @notice The maximum total number of tokens that can ever be minted.
    /// @dev Acts as a cap on supply. Decreasing is allowed (if no tokens are over that limit),
    ///      but increasing supply is forbidden after initialization.
    uint256 internal _maxSupply;

    /// @notice The per-wallet minting limit, restricting how many tokens a single address can mint.
    uint256 internal _walletLimit;

    /// @notice The address receiving royalty payments.
    address internal _royaltyReceiver;

    /// @notice The royalty amount (in basis points) for secondary sales (e.g., 100 = 1%).
    uint96 internal _royaltyBps;

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Returns the current base URI used to construct token URIs.
    /// @return The base URI as a string.
    function baseURI() public view override returns (string memory) {
        return _tokenBaseURI;
    }

    /// @notice Returns a URI representing contract-level metadata, often used by marketplaces.
    /// @return The contract-level metadata URI.
    function contractURI() public view override returns (string memory) {
        return _contractURI;
    }

    /// @notice The maximum number of tokens that can ever be minted by this contract.
    /// @return The maximum supply of tokens.
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /// @notice The maximum number of tokens any single wallet can mint.
    /// @return The minting limit per wallet.
    function walletLimit() public view returns (uint256) {
        return _walletLimit;
    }

    /// @notice The address designated to receive royalty payments on secondary sales.
    /// @return The royalty receiver address.
    function royaltyAddress() public view returns (address) {
        return _royaltyReceiver;
    }

    /// @notice The royalty rate in basis points (e.g. 100 = 1%) for secondary sales.
    /// @return The royalty fee in basis points.
    function royaltyBps() public view returns (uint256) {
        return _royaltyBps;
    }

    /// @notice Indicates whether this contract implements a given interface.
    /// @dev Supports ERC-2981 (royalties) and ERC-4906 (batch metadata updates), in addition to inherited interfaces.
    /// @param interfaceId The interface ID to check for compliance.
    /// @return True if the contract implements the specified interface, otherwise false.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721ACloneable, IERC721A)
        returns (bool)
    {
        return interfaceId == 0x2a55205a // ERC-2981 royalties
            || interfaceId == 0x49064906 // ERC-4906 metadata updates
            || ERC721ACloneable.supportsInterface(interfaceId);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Sets a new base URI for token metadata, affecting all tokens.
    /// @dev Emits a batch metadata update event if there are already minted tokens.
    /// @param newBaseURI The new base URI.
    function setBaseURI(string calldata newBaseURI) external override onlyOwner {
        _setBaseURI(newBaseURI);
    }

    /// @notice Updates the contract-level metadata URI.
    /// @dev Useful for marketplaces to display project details.
    /// @param newContractURI The new contract metadata URI.
    function setContractURI(string calldata newContractURI) external override onlyOwner {
        _setContractURI(newContractURI);

        emit ContractURIUpdated(newContractURI);
    }

    /// @notice Adjusts the maximum token supply.
    /// @dev Cannot increase beyond the original max supply. Cannot set below the current minted amount.
    /// @param newMaxSupply The new maximum supply.
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        _setMaxSupply(newMaxSupply);
    }

    /// @notice Updates the per-wallet minting limit.
    /// @dev This can be changed at any time to adjust distribution constraints.
    /// @param newWalletLimit The new per-wallet limit on minted tokens.
    function setWalletLimit(uint256 newWalletLimit) external onlyOwner {
        _setWalletLimit(newWalletLimit);
    }

    /// @notice Configures the royalty information for secondary sales.
    /// @dev Sets a new receiver and basis points for royalties. Basis points define the percentage rate.
    /// @param newReceiver The address to receive royalties.
    /// @param newBps The royalty rate in basis points (e.g., 100 = 1%).
    function setRoyaltyInfo(address newReceiver, uint96 newBps) external onlyOwner {
        _setRoyaltyInfo(newReceiver, newBps);
    }

    /// @notice Emits an event to notify clients of metadata changes for a specific token range.
    /// @dev Useful for updating external indexes after significant metadata alterations.
    /// @param fromTokenId The starting token ID in the updated range.
    /// @param toTokenId   The ending token ID in the updated range.
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) external onlyOwner {
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    /*==============================================================
    =                      INTERNAL HELPERS                        =
    ==============================================================*/

    /// @notice Internal function returning the current base URI for token metadata.
    /// @return The current base URI string.
    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }

    /// @notice Internal function setting the base URI for token metadata.
    /// @param newBaseURI The new base URI string.
    function _setBaseURI(string calldata newBaseURI) internal {
        _tokenBaseURI = newBaseURI;

        if (totalSupply() != 0) {
            // Notify EIP-4906 compliant observers of a metadata update.
            emit BatchMetadataUpdate(0, totalSupply() - 1);
        }
    }

    /// @notice Internal function setting the maximum token supply.
    /// @dev Cannot increase beyond the original max supply. Cannot set below the current minted amount.
    /// @param newMaxSupply The new maximum supply.
    function _setMaxSupply(uint256 newMaxSupply) internal {
        if (_maxSupply != 0 && newMaxSupply > _maxSupply) {
            revert MaxSupplyCannotBeIncreased();
        }

        if (newMaxSupply < _totalMinted()) {
            revert MaxSupplyCannotBeLessThanCurrentSupply();
        }

        if (newMaxSupply > 2 ** 64 - 1) {
            revert MaxSupplyCannotBeGreaterThan2ToThe64thPower();
        }

        _maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }

    /// @notice Internal function setting the per-wallet minting limit.
    /// @param newWalletLimit The new per-wallet limit on minted tokens.
    function _setWalletLimit(uint256 newWalletLimit) internal {
        _walletLimit = newWalletLimit;
        emit WalletLimitUpdated(newWalletLimit);
    }

    /// @notice Internal function setting the royalty information.
    /// @param newReceiver The address to receive royalties.
    /// @param newBps The royalty rate in basis points (e.g., 100 = 1%).
    function _setRoyaltyInfo(address newReceiver, uint96 newBps) internal {
        _royaltyReceiver = newReceiver;
        _royaltyBps = newBps;
        super._setDefaultRoyalty(_royaltyReceiver, _royaltyBps);
        emit RoyaltyInfoUpdated(_royaltyReceiver, _royaltyBps);
    }

    /// @notice Internal function setting the contract URI.
    /// @param newContractURI The new contract metadata URI.
    function _setContractURI(string calldata newContractURI) internal {
        _contractURI = newContractURI;
        emit ContractURIUpdated(newContractURI);
    }
}
