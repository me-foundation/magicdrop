// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC2981} from "solady/src/tokens/ERC2981.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

import {IERC721A} from "erc721a/contracts/IERC721A.sol";

import {ERC721AConduitPreapprovedCloneable} from "./ERC721AConduitPreapprovedCloneable.sol";
import {ERC721ACloneable} from "./ERC721ACloneable.sol";
import {ERC721AQueryableCloneable} from "./ERC721AQueryableCloneable.sol";
import {IERC721MagicDropMetadata} from "../interfaces/IERC721MagicDropMetadata.sol";

contract ERC721MagicDropMetadata is ERC721AConduitPreapprovedCloneable, IERC721MagicDropMetadata, ERC2981, Ownable {
    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    /// @notice The base URI for the token metadata
    string private _tokenBaseURI;

    /// @notice The contract URI for contract metadata
    string private _contractURI;

    /// @notice The max supply of tokens to be minted
    uint256 private _maxSupply;

    /// @notice The max number of tokens a wallet can mint
    uint256 private _walletLimit;

    /// @notice The provenance hash for guarenteeing metadata integrity
    bytes32 private _provenanceHash;

    /// @notice The royalty receiver for the collection
    address private _royaltyReceiver;

    /// @notice The royalty basis points for the collection
    uint96 private _royaltyBps;

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Returns the base URI for the token metadata, overriding the ERC721A
    /// @return The base URI for the token metadata
    function baseURI() public view override returns (string memory) {
        return _baseURI();
    }

    /// @notice Returns the contract URI for contract metadata
    /// @return The contract URI for contract metadata
    function contractURI() public view override returns (string memory) {
        return _contractURI;
    }

    /// @notice Returns the max supply of tokens to be minted
    /// @return The max supply of tokens to be minted
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    /// @notice Returns the max number of tokens a wallet can mint
    /// @return The max number of tokens a wallet can mint
    function walletLimit() public view returns (uint256) {
        return _walletLimit;
    }

    /// @notice Returns the provenance hash for guarenteeing metadata integrity
    /// @return The provenance hash for guarenteeing metadata integrity
    function provenanceHash() public view returns (bytes32) {
        return _provenanceHash;
    }

    /// @notice Returns the royalty address for the collection
    /// @return The royalty address for the collection
    function royaltyAddress() public view returns (address) {
        return _royaltyReceiver;
    }

    /// @notice Returns the royalty basis points for the collection
    /// @return The royalty basis points for the collection
    function royaltyBps() public view returns (uint256) {
        return _royaltyBps;
    }

    /// @notice Returns true if the contract implements the interface
    /// @param interfaceId The interface ID to check
    /// @return True if the contract implements the interface
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721ACloneable, IERC721A, ERC2981)
        returns (bool)
    {
        return interfaceId == 0x2a55205a // ERC-2981
            || interfaceId == 0x49064906 // ERC-4906
            || super.supportsInterface(interfaceId);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Sets the base URI for the token URIs
    /// @param newBaseURI The base URI to set
    function setBaseURI(string calldata newBaseURI) external override onlyOwner {
        _tokenBaseURI = newBaseURI;

        if (totalSupply() != 0) {
            emit BatchMetadataUpdate(0, totalSupply() - 1);
        }
    }

    /// @notice Sets the contract URI for contract metadata
    /// @param newContractURI The contract URI to set
    function setContractURI(string calldata newContractURI) external override onlyOwner {
        _contractURI = newContractURI;

        emit ContractURIUpdated(newContractURI);
    }

    /// @notice Sets the max supply of tokens to be minted
    /// @param newMaxSupply The max supply of tokens to be minted
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        // Ensure the new max supply is not greater than the current max supply
        if (newMaxSupply > _maxSupply) {
            revert MaxSupplyCannotBeIncreased();
        }

        // Ensure the new max supply is greater than the current supply
        if (newMaxSupply < totalSupply()) {
            revert MaxSupplyCannotBeLessThanCurrentSupply();
        }

        _maxSupply = newMaxSupply;

        emit MaxSupplyUpdated(newMaxSupply);
    }

    /// @notice Sets the max number of tokens a wallet can mint
    /// @param newWalletLimit The max number of tokens a wallet can mint
    function setWalletLimit(uint256 newWalletLimit) external onlyOwner {
        _walletLimit = newWalletLimit;

        emit WalletLimitUpdated(newWalletLimit);
    }

    /// @notice Sets the provenance hash for guarenteeing metadata integrity
    ///     for random reveals. Created using a hash of the metadata.
    /// Reverts if the provenance hash is updated after any tokens have been minted.
    /// @param newProvenanceHash The provenance hash to set
    function setProvenanceHash(bytes32 newProvenanceHash) external onlyOwner {
        if (_totalMinted() > 0) {
            revert ProvenanceHashCannotBeUpdated();
        }

        bytes32 oldProvenanceHash = _provenanceHash;
        _provenanceHash = newProvenanceHash;

        emit ProvenanceHashUpdated(oldProvenanceHash, newProvenanceHash);
    }

    /// @notice Sets the royalty info for the contract
    /// @param newReceiver The address to receive royalties
    /// @param newBps The royalty basis points (100 = 1%)
    function setRoyaltyInfo(address newReceiver, uint96 newBps) external onlyOwner {
        _royaltyReceiver = newReceiver;
        _royaltyBps = newBps;

        super._setDefaultRoyalty(_royaltyReceiver, _royaltyBps);

        emit RoyaltyInfoUpdated(_royaltyReceiver, _royaltyBps);
    }

    /// @notice Emit an event notifying metadata updates for a range of token ids (EIP-4906)
    /// @param fromTokenId The start token id.
    /// @param toTokenId   The end token id.
    function emitBatchMetadataUpdate(uint256 fromTokenId, uint256 toTokenId) external onlyOwner {
        emit BatchMetadataUpdate(fromTokenId, toTokenId);
    }

    /*==============================================================
    =                      INTERNAL HELPERS                        =
    ==============================================================*/

    /// @notice Returns the base URI for the token metadata, overriding the ERC721A
    /// @return The base URI for the token metadata
    function _baseURI() internal view override returns (string memory) {
        return _tokenBaseURI;
    }
}
