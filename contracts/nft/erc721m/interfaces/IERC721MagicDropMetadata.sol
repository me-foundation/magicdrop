// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IERC2981} from "@openzeppelin/contracts/interfaces/IERC2981.sol";

interface IERC721MagicDropMetadata is IERC2981 {
    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    /// @notice Emitted when the contract URI is updated.
    /// @param _contractURI The new contract URI.
    event ContractURIUpdated(string _contractURI);

    /// @notice Emitted when the max supply is updated.
    /// @param _maxSupply The new max supply.
    event MaxSupplyUpdated(uint256 _maxSupply);

    /// @notice Emitted when the wallet limit is updated.
    /// @param _walletLimit The new wallet limit.
    event WalletLimitUpdated(uint256 _walletLimit);

    /// @notice Emitted when the provenance hash is updated.
    /// @param oldHash The old provenance hash.
    /// @param newHash The new provenance hash.
    event ProvenanceHashUpdated(bytes32 oldHash, bytes32 newHash);

    /// @notice Emitted when the royalty info is updated.
    /// @param receiver The new royalty receiver.
    /// @param bps The new royalty basis points.
    event RoyaltyInfoUpdated(address receiver, uint256 bps);

    /// @notice Emitted when the metadata is updated. (EIP-4906)
    /// @param _fromTokenId The starting token ID.
    /// @param _toTokenId The ending token ID.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    /// @notice Throw when the provenance hash cannot be updated.
    error ProvenanceHashCannotBeUpdated();

    /// @notice Throw when the max supply is exceeded.
    error CannotExceedMaxSupply();

    /// @notice Throw when the max supply is less than the current supply.
    error MaxSupplyCannotBeLessThanCurrentSupply();

    /// @notice Throw when trying to increase the max supply.
    error MaxSupplyCannotBeIncreased();

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Returns the base URI used to construct token URIs
    /// @dev This is concatenated with the token ID to form the complete token URI
    /// @return The base URI string that prefixes all token URIs
    function baseURI() external view returns (string memory);

    /// @notice Returns the contract-level metadata URI
    /// @dev Used by marketplaces like MagicEden to display collection information
    /// @return The URI string pointing to the contract's metadata JSON
    function contractURI() external view returns (string memory);

    /// @notice Returns the maximum number of tokens that can be minted
    /// @dev This value cannot be increased once set, only decreased
    /// @return The maximum supply cap for the collection
    function maxSupply() external view returns (uint256);

    /// @notice Returns the maximum number of tokens that can be minted per wallet
    /// @dev Used to prevent excessive concentration of tokens in single wallets
    /// @return The maximum number of tokens allowed per wallet address
    function walletLimit() external view returns (uint256);

    /// @notice Returns the provenance hash for the collection
    /// @dev Used to prove that the token metadata/artwork hasn't been changed after mint
    /// @return The 32-byte provenance hash of the collection
    function provenanceHash() external view returns (bytes32);

    /// @notice Returns the address that receives royalty payments
    /// @dev Used in conjunction with royaltyBps for EIP-2981 royalty standard
    /// @return The address designated to receive royalty payments
    function royaltyAddress() external view returns (address);

    /// @notice Returns the royalty percentage in basis points (1/100th of a percent)
    /// @dev 100 basis points = 1%. Used in EIP-2981 royalty calculations
    /// @return The royalty percentage in basis points (e.g., 250 = 2.5%)
    function royaltyBps() external view returns (uint256);

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Sets the base URI for all token metadata
    /// @dev This is a critical function that determines where all token metadata is hosted
    ///      Changing this will update the metadata location for all tokens in the collection
    /// @param baseURI The new base URI string that will prefix all token URIs
    function setBaseURI(string calldata baseURI) external;

    /// @notice Sets the contract-level metadata URI
    /// @dev This metadata is used by marketplaces to display collection information
    ///      Should point to a JSON file following collection metadata standards
    /// @param contractURI The new URI string pointing to the contract's metadata JSON
    function setContractURI(string calldata contractURI) external;

    /// @notice Updates the maximum supply cap for the collection
    /// @dev Can only decrease the max supply, never increase it
    ///      Must be greater than or equal to the current total supply
    /// @param maxSupply The new maximum number of tokens that can be minted
    function setMaxSupply(uint256 maxSupply) external;

    /// @notice Updates the per-wallet token holding limit
    /// @dev Used to prevent token concentration and ensure fair distribution
    ///      Setting this to 0 effectively removes the wallet limit
    /// @param walletLimit The new maximum number of tokens allowed per wallet
    function setWalletLimit(uint256 walletLimit) external;

    /// @notice Sets the provenance hash for the collection
    /// @dev Should only be called once before the collection is revealed
    ///      Used to verify the integrity of the artwork/metadata after reveal
    /// @param provenanceHash The 32-byte hash representing the collection's provenance
    function setProvenanceHash(bytes32 provenanceHash) external;

    /// @notice Updates the royalty configuration for the collection
    /// @dev Implements EIP-2981 for NFT royalty standards
    ///      The bps (basis points) must be between 0 and 10000 (0% to 100%)
    /// @param newReceiver The address that will receive future royalty payments
    /// @param newBps The royalty percentage in basis points (e.g., 250 = 2.5%)
    function setRoyaltyInfo(address newReceiver, uint96 newBps) external;
}
