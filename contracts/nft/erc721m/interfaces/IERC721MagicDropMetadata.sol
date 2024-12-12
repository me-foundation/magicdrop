// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IMagicDropMetadata} from "contracts/common/interfaces/IMagicDropMetadata.sol";

interface IERC721MagicDropMetadata is IMagicDropMetadata {
    /// @notice Emitted when the wallet limit is updated.
    /// @param _walletLimit The new wallet limit.
    event WalletLimitUpdated(uint256 _walletLimit);

    /// @notice Emitted when the max supply is updated.
    /// @param newMaxSupply The new max supply.
    event MaxSupplyUpdated(uint256 newMaxSupply);

    /// @notice Thrown when a mint would exceed the wallet-specific minting limit.
    error WalletLimitExceeded();

    /// @notice Returns the maximum number of tokens that can be minted per wallet
    /// @dev Used to prevent excessive concentration of tokens in single wallets
    /// @return The maximum number of tokens allowed per wallet address
    function walletLimit() external view returns (uint256);

    /// @notice Returns the maximum number of tokens that can be minted
    /// @dev This value cannot be increased once set, only decreased
    /// @return The maximum supply cap for the collection
    function maxSupply() external view returns (uint256);

    /// @notice Updates the per-wallet token holding limit
    /// @dev Used to prevent token concentration and ensure fair distribution
    ///      Setting this to 0 effectively removes the wallet limit
    /// @param walletLimit The new maximum number of tokens allowed per wallet
    function setWalletLimit(uint256 walletLimit) external;

    /// @notice Updates the maximum supply cap for the collection
    /// @dev Can only decrease the max supply, never increase it
    ///      Must be greater than or equal to the current total supply
    /// @param maxSupply The new maximum number of tokens that can be minted
    function setMaxSupply(uint256 maxSupply) external;
}
