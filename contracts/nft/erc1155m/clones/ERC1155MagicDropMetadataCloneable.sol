// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";

import {ERC1155} from "solady/src/tokens/ext/zksync/ERC1155.sol";
import {IERC1155MagicDropMetadata} from "../interfaces/IERC1155MagicDropMetadata.sol";
import {ERC1155ConduitPreapprovedCloneable} from "./ERC1155ConduitPreapprovedCloneable.sol";

/// @title ERC1155MagicDropMetadataCloneable
/// @notice A cloneable ERC-1155 implementation that supports adjustable metadata URIs, royalty configuration.
///         Inherits conduit-based preapprovals, making distribution more gas-efficient.
contract ERC1155MagicDropMetadataCloneable is
    ERC1155ConduitPreapprovedCloneable,
    IERC1155MagicDropMetadata,
    ERC2981,
    Ownable,
    Initializable
{
    /// @dev The name of the collection.
    string internal _name;

    /// @dev The symbol of the collection.
    string internal _symbol;

    /// @dev The contract URI.
    string internal _contractURI;

    /// @dev The base URI for the collection.
    string internal _baseURI;

    /// @dev The address that receives royalty payments.
    address internal _royaltyReceiver;

    /// @dev The royalty basis points.
    uint96 internal _royaltyBps;

    /// @dev The total supply of each token.
    mapping(uint256 => TokenSupply) internal _tokenSupply;

    /// @dev The maximum number of tokens that can be minted by a single wallet.
    mapping(uint256 => uint256) internal _walletLimit;

    /// @dev The total number of tokens minted by each user per token.
    mapping(address => mapping(uint256 => uint256))
        internal _totalMintedByUserPerToken;

    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @notice Initializes the contract with a name, symbol, and owner.
    /// @dev Can only be called once. It sets the owner, emits a deploy event, and prepares the token for minting stages.
    /// @param name_ The ERC-1155 name of the collection.
    /// @param symbol_ The ERC-1155 symbol of the collection.
    /// @param owner_ The address designated as the initial owner of the contract.
    function __ERC1155MagicDropMetadataCloneable__init(
        string memory name_,
        string memory symbol_,
        address owner_
    ) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
        _initializeOwner(owner_);

        emit MagicDropTokenDeployed();
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Returns the name of the collection.
    function name() public view returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the collection.
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the current base URI used to construct token URIs.
    function baseURI() public view override returns (string memory) {
        return _baseURI;
    }

    /// @notice Returns a URI representing contract-level metadata, often used by marketplaces.
    function contractURI() public view override returns (string memory) {
        return _contractURI;
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

    /// @notice The maximum number of tokens that can ever be minted by this contract.
    /// @param tokenId The ID of the token.
    /// @return The maximum supply of tokens.
    function maxSupply(uint256 tokenId) public view returns (uint256) {
        return _tokenSupply[tokenId].maxSupply;
    }

    /// @notice Return the total supply of a token.
    /// @param tokenId The ID of the token.
    /// @return The total supply of token.
    function totalSupply(uint256 tokenId) public view returns (uint256) {
        return _tokenSupply[tokenId].totalSupply;
    }

    /// @notice Return the total number of tokens minted for a specific token.
    /// @param tokenId The ID of the token.
    /// @return The total number of tokens minted.
    function totalMinted(uint256 tokenId) public view returns (uint256) {
        return _tokenSupply[tokenId].totalMinted;
    }

    /// @notice Return the total number of tokens minted by a specific address for a specific token.
    /// @param user The address to query.
    /// @param tokenId The ID of the token.
    /// @return The total number of tokens minted by the specified address for the specified token.
    function totalMintedByUser(
        address user,
        uint256 tokenId
    ) public view returns (uint256) {
        return _totalMintedByUserPerToken[user][tokenId];
    }

    /// @notice Return the maximum number of tokens any single wallet can mint for a specific token.
    /// @param tokenId The ID of the token.
    /// @return The minting limit per wallet.
    function walletLimit(uint256 tokenId) public view returns (uint256) {
        return _walletLimit[tokenId];
    }

    /// @notice Indicates whether this contract implements a given interface.
    /// @dev Supports ERC-2981 (royalties) and ERC-4906 (batch metadata updates), in addition to inherited interfaces.
    /// @param interfaceId The interface ID to check for compliance.
    /// @return True if the contract implements the specified interface, otherwise false.
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return
            interfaceId == 0x2a55205a || // ERC-2981 royalties
            interfaceId == 0x49064906 || // ERC-4906 metadata updates
            interfaceId == type(IERC1155MagicDropMetadata).interfaceId ||
            ERC1155.supportsInterface(interfaceId);
    }

    /// @notice Returns the URI for a given token ID.
    /// @dev This returns the base URI for all tokens.
    /// @return The URI for the token.
    function uri(
        uint256 /* tokenId */
    ) public view override returns (string memory) {
        return _baseURI;
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Sets a new base URI for token metadata, affecting all tokens.
    /// @dev Emits a batch metadata update event if there are already minted tokens.
    /// @param newBaseURI The new base URI.
    function setBaseURI(
        string calldata newBaseURI
    ) external override onlyOwner {
        _setBaseURI(newBaseURI);
    }

    /// @notice Updates the contract-level metadata URI.
    /// @dev Useful for marketplaces to display project details.
    /// @param newContractURI The new contract metadata URI.
    function setContractURI(
        string calldata newContractURI
    ) external override onlyOwner {
        _setContractURI(newContractURI);
    }

    /// @notice Adjusts the maximum token supply.
    /// @dev Cannot increase beyond the original max supply. Cannot set below the current minted amount.
    /// @param tokenId The ID of the token to update.
    /// @param newMaxSupply The new maximum supply.
    function setMaxSupply(
        uint256 tokenId,
        uint256 newMaxSupply
    ) external onlyOwner {
        _setMaxSupply(tokenId, newMaxSupply);
    }

    /// @notice Updates the per-wallet minting limit.
    /// @dev This can be changed at any time to adjust distribution constraints.
    /// @param tokenId The ID of the token.
    /// @param newWalletLimit The new per-wallet limit on minted tokens.
    function setWalletLimit(
        uint256 tokenId,
        uint256 newWalletLimit
    ) external onlyOwner {
        _setWalletLimit(tokenId, newWalletLimit);
    }

    /// @notice Configures the royalty information for secondary sales.
    /// @dev Sets a new receiver and basis points for royalties. Basis points define the percentage rate.
    /// @param newReceiver The address to receive royalties.
    /// @param newBps The royalty rate in basis points (e.g., 100 = 1%).
    function setRoyaltyInfo(
        address newReceiver,
        uint96 newBps
    ) external onlyOwner {
        _setRoyaltyInfo(newReceiver, newBps);
    }

    /// @notice Emits an event to notify clients of metadata changes for a specific token range.
    /// @dev Useful for updating external indexes after significant metadata alterations.
    /// @param fromTokenId The starting token ID in the updated range.
    /// @param toTokenId   The ending token ID in the updated range.
    function emitBatchMetadataUpdate(
        uint256 fromTokenId,
        uint256 toTokenId
    ) external onlyOwner {
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    /*==============================================================
    =                      INTERNAL HELPERS                        =
    ==============================================================*/

    /// @notice Internal function setting the base URI for token metadata.
    /// @param newBaseURI The new base URI string.
    function _setBaseURI(string calldata newBaseURI) internal {
        _baseURI = newBaseURI;

        // Notify EIP-4906 compliant observers of a metadata update.
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /// @notice Internal function setting the contract URI.
    /// @param newContractURI The new contract metadata URI.
    function _setContractURI(string calldata newContractURI) internal {
        _contractURI = newContractURI;

        emit ContractURIUpdated(newContractURI);
    }

    /// @notice Internal function setting the royalty information.
    /// @param newReceiver The address to receive royalties.
    /// @param newBps The royalty rate in basis points (e.g., 100 = 1%).
    function _setRoyaltyInfo(address newReceiver, uint96 newBps) internal {
        _royaltyReceiver = newReceiver;
        _royaltyBps = newBps;
        super._setDefaultRoyalty(newReceiver, newBps);
        emit RoyaltyInfoUpdated(newReceiver, newBps);
    }

    /// @notice Internal function setting the maximum token supply.
    /// @dev Cannot increase beyond the original max supply. Cannot set below the current minted amount.
    /// @param tokenId The ID of the token.
    /// @param newMaxSupply The new maximum supply.
    function _setMaxSupply(uint256 tokenId, uint256 newMaxSupply) internal {
        uint256 oldMaxSupply = _tokenSupply[tokenId].maxSupply;
        if (oldMaxSupply != 0 && newMaxSupply > oldMaxSupply) {
            revert MaxSupplyCannotBeIncreased();
        }

        if (newMaxSupply < _tokenSupply[tokenId].totalMinted) {
            revert MaxSupplyCannotBeLessThanCurrentSupply();
        }

        if (newMaxSupply > 2 ** 64 - 1) {
            revert MaxSupplyCannotBeGreaterThan2ToThe64thPower();
        }

        _tokenSupply[tokenId].maxSupply = uint64(newMaxSupply);

        emit MaxSupplyUpdated(tokenId, oldMaxSupply, newMaxSupply);
    }

    /// @notice Internal function setting the per-wallet minting limit.
    /// @param tokenId The ID of the token.
    /// @param newWalletLimit The new per-wallet limit on minted tokens.
    function _setWalletLimit(uint256 tokenId, uint256 newWalletLimit) internal {
        _walletLimit[tokenId] = newWalletLimit;
        emit WalletLimitUpdated(tokenId, newWalletLimit);
    }
}
