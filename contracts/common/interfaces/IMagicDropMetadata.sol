// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface IMagicDropMetadata {
    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    /// @notice Emitted when the contract URI is updated.
    /// @param _contractURI The new contract URI.
    event ContractURIUpdated(string _contractURI);

    /// @notice Emitted when the royalty info is updated.
    /// @param receiver The new royalty receiver.
    /// @param bps The new royalty basis points.
    event RoyaltyInfoUpdated(address receiver, uint256 bps);

    /// @notice Emitted when the metadata is updated. (EIP-4906)
    /// @param _fromTokenId The starting token ID.
    /// @param _toTokenId The ending token ID.
    event BatchMetadataUpdate(uint256 _fromTokenId, uint256 _toTokenId);

    /// @notice Emitted once when the token contract is deployed and initialized.
    event MagicDropTokenDeployed();

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    /// @notice Throw when the max supply is exceeded.
    error CannotExceedMaxSupply();

    /// @notice Throw when the max supply is less than the current supply.
    error MaxSupplyCannotBeLessThanCurrentSupply();

    /// @notice Throw when trying to increase the max supply.
    error MaxSupplyCannotBeIncreased();

    /// @notice Throw when the max supply is greater than 2^64.
    error MaxSupplyCannotBeGreaterThan2ToThe64thPower();

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

    /// @notice Updates the royalty configuration for the collection
    /// @dev Implements EIP-2981 for NFT royalty standards
    ///      The bps (basis points) must be between 0 and 10000 (0% to 100%)
    /// @param newReceiver The address that will receive future royalty payments
    /// @param newBps The royalty percentage in basis points (e.g., 250 = 2.5%)
    function setRoyaltyInfo(address newReceiver, uint96 newBps) external;
}