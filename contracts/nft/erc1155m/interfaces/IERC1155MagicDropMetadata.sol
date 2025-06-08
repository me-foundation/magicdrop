// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IMagicDropMetadata} from "contracts/common/interfaces/IMagicDropMetadata.sol";

interface IERC1155MagicDropMetadata is IMagicDropMetadata {
    struct TokenSupply {
        /// @notice The maximum number of tokens that can be minted.
        uint64 maxSupply;
        /// @notice The total number of tokens minted minus the number of tokens burned.
        uint64 totalSupply;
        /// @notice The total number of tokens minted.
        uint64 totalMinted;
    }

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    /// @notice Emitted when the max supply is updated.
    /// @param _tokenId The token ID.
    /// @param _oldMaxSupply The old max supply.
    /// @param _newMaxSupply The new max supply.
    event MaxSupplyUpdated(uint256 _tokenId, uint256 _oldMaxSupply, uint256 _newMaxSupply);

    /// @notice Emitted when the wallet limit is updated.
    /// @param _tokenId The token ID.
    /// @param _walletLimit The new wallet limit.
    event WalletLimitUpdated(uint256 _tokenId, uint256 _walletLimit);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    /// @notice Thrown when a mint would exceed the wallet-specific minting limit.
    /// @param _tokenId The token ID.
    error WalletLimitExceeded(uint256 _tokenId);

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Returns the name of the token
    function name() external view returns (string memory);

    /// @notice Returns the symbol of the token
    function symbol() external view returns (string memory);

    /// @notice Returns the maximum number of tokens that can be minted
    /// @dev This value cannot be increased once set, only decreased
    /// @param tokenId The ID of the token
    /// @return The maximum supply cap for the collection
    function maxSupply(uint256 tokenId) external view returns (uint256);

    /// @notice Returns the total number of tokens minted minus the number of tokens burned
    /// @param tokenId The ID of the token
    /// @return The total number of tokens minted minus the number of tokens burned
    function totalSupply(uint256 tokenId) external view returns (uint256);

    /// @notice Returns the total number of tokens minted
    /// @param tokenId The ID of the token
    /// @return The total number of tokens minted
    function totalMinted(uint256 tokenId) external view returns (uint256);

    /// @notice Returns the maximum number of tokens that can be minted per wallet
    /// @dev Used to prevent excessive concentration of tokens in single wallets
    /// @param tokenId The ID of the token
    /// @return The maximum number of tokens allowed per wallet address
    function walletLimit(uint256 tokenId) external view returns (uint256);

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Updates the maximum supply cap for the collection
    /// @dev Can only decrease the max supply, never increase it
    ///      Must be greater than or equal to the current total supply
    /// @param tokenId The ID of the token.
    /// @param newMaxSupply The new maximum number of tokens that can be minted
    function setMaxSupply(uint256 tokenId, uint256 newMaxSupply) external;

    /// @notice Updates the per-wallet token holding limit
    /// @dev Used to prevent token concentration and ensure fair distribution
    ///      Setting this to 0 effectively removes the wallet limit
    /// @param tokenId The ID of the token.
    /// @param walletLimit The new maximum number of tokens allowed per wallet
    function setWalletLimit(uint256 tokenId, uint256 walletLimit) external;
}
