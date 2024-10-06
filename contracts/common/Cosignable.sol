// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

/// @title Cosignable
/// @notice Abstract contract for implementing cosigner functionality
/// @dev This contract should be inherited by contracts that require cosigner approval
abstract contract Cosignable {
    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    /// @notice The address of the cosigner
    address internal _cosigner;
    /// @notice The number of seconds after which a timestamp is considered expired
    uint256 internal _timestampExpirySeconds;

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    /// @notice Emitted when a new cosigner is set
    /// @param cosigner The address of the new cosigner
    event SetCosigner(address indexed cosigner);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    /// @notice Thrown when an operation requires a cosigner but none is set
    error CosignerNotSet();
    /// @notice Thrown when the provided cosign signature is invalid
    error InvalidCosignSignature();
    /// @notice Thrown when the provided timestamp has expired
    error TimestampExpired();

    /*==============================================================
    =                      PUBLIC WRITE METHODS                    =
    ==============================================================*/

    /// @notice Sets the cosigner address
    /// @dev This function should be overridden with appropriate access control
    /// @param cosigner The address of the new cosigner
    function setCosigner(address cosigner) external virtual;

    /// @notice Sets the expiry time for timestamps
    /// @param timestampExpirySeconds The number of seconds after which a timestamp is considered expired
    function setTimestampExpirySeconds(uint256 timestampExpirySeconds) external virtual {
        _timestampExpirySeconds = timestampExpirySeconds;
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Generates a digest for cosigning
    /// @param minter The address of the minter
    /// @param qty The quantity to mint
    /// @param waiveMintFee Whether to waive the mint fee
    /// @param timestamp The timestamp of the request
    /// @param cosignNonce A nonce to prevent replay attacks
    /// @return The generated digest
    function getCosignDigest(address minter, uint32 qty, bool waiveMintFee, uint256 timestamp, uint256 cosignNonce)
        public
        view
        returns (bytes32)
    {
        if (_cosigner == address(0)) revert CosignerNotSet();

        return SignatureCheckerLib.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    address(this), minter, qty, waiveMintFee, _cosigner, timestamp, block.chainid, cosignNonce
                )
            )
        );
    }

    /// @notice Verifies the validity of a cosign signature
    /// @param minter The address of the minter
    /// @param qty The quantity to mint
    /// @param timestamp The timestamp of the request
    /// @param signature The cosigner's signature
    /// @param cosignNonce A nonce to prevent replay attacks
    /// @return A boolean indicating whether the mint fee should be waived
    function assertValidCosign(
        address minter,
        uint32 qty,
        uint256 timestamp,
        bytes memory signature,
        uint256 cosignNonce
    ) public view returns (bool) {
        if (
            SignatureCheckerLib.isValidSignatureNow(
                _cosigner, getCosignDigest(minter, qty, true, timestamp, cosignNonce), signature
            )
        ) {
            return true;
        }

        if (
            SignatureCheckerLib.isValidSignatureNow(
                _cosigner, getCosignDigest(minter, qty, false, timestamp, cosignNonce), signature
            )
        ) {
            return false;
        }

        revert InvalidCosignSignature();
    }

    /*==============================================================
    =                       INTERNAL HELPERS                       =
    ==============================================================*/

    /// @notice Checks if a given timestamp is valid
    /// @param timestamp The timestamp to check
    /// @dev Reverts if the timestamp has expired
    function _assertValidTimestamp(uint256 timestamp) internal view {
        if (timestamp < block.timestamp - _timestampExpirySeconds) {
            revert TimestampExpired();
        }
    }
}
