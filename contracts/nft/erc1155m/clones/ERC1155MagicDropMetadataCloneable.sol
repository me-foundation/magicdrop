// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";

import {IERC1155MagicDropMetadata} from "../interfaces/IERC1155MagicDropMetadata.sol";

contract ERC1155MagicDropMetadataCloneable is
    ERC1155ConduitPreapprovedCloneable,
    IERC1155MagicDropMetadata,
    ERC2981,
    Ownable,
    Initializable
{
    /// @dev The total supply of each token.
    mapping(uint256 => TokenSupply) internal _tokenSupply;

    /// @dev The maximum number of tokens that can be minted by a single wallet.
    mapping(uint256 => uint256) internal _walletLimit;

    /// @dev The total number of tokens minted by each user per token.
    mapping(address => mapping(uint256 => uint256)) internal _totalMintedByUserPerToken;

    /// @dev The name of the collection.
    string internal _name;

    /// @dev The symbol of the collection.
    string internal _symbol;

    /// @dev The contract URI.
    string internal _contractURI;

    /// @dev The base URI for the collection.
    string internal _baseURI;

    /// @dev The provenance hash of the collection.
    bytes32 internal _provenanceHash;

    /// @dev The address that receives royalty payments.
    address internal _royaltyReceiver;

    /// @dev The royalty basis points.
    uint256 internal _royaltyBps;

    event MagicDropTokenDeployed();

    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @notice Initializes the contract with a name, symbol, and owner.
    /// @dev Can only be called once. It sets the owner, emits a deploy event, and prepares the token for minting stages.
    /// @param _name The ERC-1155 name of the collection.
    /// @param _symbol The ERC-1155 symbol of the collection.
    /// @param _owner The address designated as the initial owner of the contract.
    function __ERC1155MagicDropMetadataCloneable__init(string memory name_, string memory symbol_, address owner_)
        internal
        onlyInitializing
    {
        _name = name_;
        _symbol = symbol_;
        _initializeOwner(owner_);
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Returns the current base URI used to construct token URIs.
    /// @return The base URI as a string.
    function baseURI() public view override returns (string memory) {
        return _baseURI;
    }

    /// @notice Returns a URI representing contract-level metadata, often used by marketplaces.
    /// @return The contract-level metadata URI.
    function contractURI() public view override returns (string memory) {
        return _contractURI;
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

    /// @notice Return the maximum number of tokens any single wallet can mint for a specific token.
    /// @param tokenId The ID of the token.
    /// @return The minting limit per wallet.
    function walletLimit(uint256 tokenId) public view returns (uint256) {
        return _walletLimit[tokenId];
    }

    /// @notice The assigned provenance hash used to ensure the integrity of the metadata ordering.
    /// @return The provenance hash of the token.
    function provenanceHash(uint256 tokenId) public view returns (bytes32) {
        return _provenanceHash[tokenId];
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
        override(ERC1155ConduitPreapprovedCloneable, IERC1155ConduitPreapproved, ERC2981)
        returns (bool)
    {
        return interfaceId == 0x2a55205a // ERC-2981 royalties
            || interfaceId == 0x49064906 // ERC-4906 metadata updates
            || super.supportsInterface(interfaceId);
    }

    /// @notice Returns the URI for a given token ID.
    /// @dev This returns the base URI for all tokens.
    /// @param tokenId The ID of the token.
    /// @return The URI for the token.
    function uri(uint256 /* tokenId */) public view returns (string memory) {
        return _baseURI;
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
    }

    /// @notice Adjusts the maximum token supply.
    /// @dev Cannot increase beyond the original max supply. Cannot set below the current minted amount.
    /// @param tokenId The ID of the token to update.
    /// @param newMaxSupply The new maximum supply.
    function setMaxSupply(uint256 tokenId, uint256 newMaxSupply) external onlyOwner {
        _setMaxSupply(tokenId, newMaxSupply);
    }


    /// @notice Updates the per-wallet minting limit.
    /// @dev This can be changed at any time to adjust distribution constraints.
    /// @param tokenId The ID of the token.
    /// @param newWalletLimit The new per-wallet limit on minted tokens.
    function setWalletLimit(uint256 tokenId, uint256 newWalletLimit) external onlyOwner {
        _setWalletLimit(tokenId, newWalletLimit);
    }

    /// @notice Sets the provenance hash, used to verify metadata integrity and prevent tampering.
    /// @dev Can only be set before any tokens are minted.
    /// @param newProvenanceHash The new provenance hash.
    function setProvenanceHash(bytes32 newProvenanceHash) external onlyOwner {
        _setProvenanceHash(newProvenanceHash);
    }

    /// @notice Configures the royalty information for secondary sales.
    /// @dev Sets a new receiver and basis points for royalties. Basis points define the percentage rate.
    /// @param newReceiver The address to receive royalties.
    /// @param newBps The royalty rate in basis points (e.g., 100 = 1%).
    function setRoyaltyInfo(address newReceiver, uint96 newBps) external onlyOwner {
        _setRoyaltyInfo(newReceiver, newBps);
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
    /// @param tokenId The ID of the token.
    /// @param newMaxSupply The new maximum supply.
    function _setMaxSupply(uint256 tokenId, uint256 newMaxSupply) internal {
        if (_maxSupply != 0 && newMaxSupply > _maxSupply) {
            revert MaxSupplyCannotBeIncreased();
        }

        if (newMaxSupply < _tokenSupply[tokenId].maxSupply) {
            revert MaxSupplyCannotBeLessThanCurrentSupply();
        }

        if (newMaxSupply > 2 ** 64 - 1) {
            revert MaxSupplyCannotBeGreaterThan2ToThe64thPower();
        }

        _tokenSupply[tokenId].maxSupply = uint64(newMaxSupply);

        emit MaxSupplyUpdated(tokenId, newMaxSupply);
    }

    /// @notice Internal function setting the per-wallet minting limit.
    /// @param tokenId The ID of the token.
    /// @param newWalletLimit The new per-wallet limit on minted tokens.
    function _setWalletLimit(uint256 tokenId, uint256 newWalletLimit) internal {
        _walletLimit[tokenId] = newWalletLimit;
        emit WalletLimitUpdated(tokenId, newWalletLimit);
    }

    /// @notice Internal function setting the provenance hash.
    /// @param tokenId The ID of the token.
    /// @param newProvenanceHash The new provenance hash.
    function _setProvenanceHash(uint256 tokenId, bytes32 newProvenanceHash) internal {
        if (_tokenSupply[tokenId].totalMinted > 0) {
            revert ProvenanceHashCannotBeUpdated();
        }

        bytes32 oldProvenanceHash = _provenanceHash[tokenId];
        _provenanceHash[tokenId] = newProvenanceHash;
        emit ProvenanceHashUpdated(tokenId, oldProvenanceHash, newProvenanceHash);
    }
}
