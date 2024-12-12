// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {IMagicDropMetadata} from "contracts/common/IMagicDropMetadata.sol";

interface IERC721MagicDropMetadata is IMagicDropMetadata {
    /// @notice Emitted when the wallet limit is updated.
    /// @param _walletLimit The new wallet limit.
    event WalletLimitUpdated(uint256 _walletLimit);

    /// @notice Emitted when the provenance hash is updated.
    /// @param oldHash The old provenance hash.
    /// @param newHash The new provenance hash.
    event ProvenanceHashUpdated(bytes32 oldHash, bytes32 newHash);

    /// @notice Throw when the provenance hash cannot be updated.
    error ProvenanceHashCannotBeUpdated();

    /// @notice Thrown when a mint would exceed the wallet-specific minting limit.
    error WalletLimitExceeded();

    /// @notice Returns the provenance hash for the collection
    /// @dev Used to prove that the token metadata/artwork hasn't been changed after mint
    /// @return The 32-byte provenance hash of the collection
    function provenanceHash() external view returns (bytes32);

    /// @notice Returns the maximum number of tokens that can be minted per wallet
    /// @dev Used to prevent excessive concentration of tokens in single wallets
    /// @return The maximum number of tokens allowed per wallet address
    function walletLimit() external view returns (uint256);

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
}
