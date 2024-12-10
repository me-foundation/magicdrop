// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

struct PublicStage {
    /// @dev The start time of the public mint stage.
    uint256 startTime;
    /// @dev The end time of the public mint stage.
    uint256 endTime;
    /// @dev The price of the public mint stage.
    uint256 price;
}

struct AllowlistStage {
    /// @dev The start time of the allowlist mint stage.
    uint256 startTime;
    /// @dev The end time of the allowlist mint stage.
    uint256 endTime;
    /// @dev The price of the allowlist mint stage.
    uint256 price;
    /// @dev The merkle root of the allowlist.
    bytes32 merkleRoot;
}

struct SetupConfig {
    /// @dev The maximum number of tokens that can be minted.
    ///      - Can be decreased if current supply < new max supply
    ///      - Cannot be increased once set
    uint256 maxSupply;
    /// @dev The maximum number of tokens that can be minted per wallet
    /// @notice A value of 0 indicates unlimited mints per wallet
    uint256 walletLimit;
    /// @dev The base URI of the token.
    string baseURI;
    /// @dev The contract URI of the token.
    string contractURI;
    /// @dev The public mint stage.
    PublicStage publicStage;
    /// @dev The allowlist mint stage.
    AllowlistStage allowlistStage;
    /// @dev The payout recipient of the token.
    address payoutRecipient;
    /// @dev The provenance hash of the token.
    /// @notice This is used to ensure the metadata is not tampered with.
    ///     A value of 0 is used to indicate that the provenance hash is not set.
    bytes32 provenanceHash;
}
