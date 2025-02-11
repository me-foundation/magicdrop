// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

struct MintStageInfo {
    uint80 price;
    uint32 walletLimit; // 0 for unlimited
    bytes32 merkleRoot; // 0x0 for no presale enforced
    uint24 maxStageSupply; // 0 for unlimited
    uint256 startTimeUnixSeconds;
    uint256 endTimeUnixSeconds;
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
    /// @dev The mint stages of the token.
    MintStageInfo[] stages;
    /// @dev The payout recipient of the token.
    address payoutRecipient;
    /// @dev The royalty recipient of the token.
    address royaltyRecipient;
    /// @dev The royalty basis points of the token.
    uint96 royaltyBps;
    /// @dev The mint fee per token.
    uint256 mintFee;
}
