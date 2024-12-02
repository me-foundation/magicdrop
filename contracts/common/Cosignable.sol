// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

/// @title Cosignable
/// @notice Abstract contract for implementing cosigner functionality
/// @dev This contract should be inherited by contracts that require cosigner approval
abstract contract Cosignable {
    /*==============================================================
    =                            STRUCTS                           =
    ==============================================================*/

    struct CosignerStorage {
        /// @notice The address of the cosigner
        address cosigner;
        /// @notice The number of seconds after which a timestamp is considered expired
        uint256 timestampExpirySeconds;
    }

    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    // keccak256(abi.encode(uint256(keccak256("magicdrop.common.Cosignable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant COSIGNER_STORAGE =
        0x7a773b7a6a1a56c71d7c444f8c85789ff8084674fcb1b3c236aa236aec141e00;

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    /// @notice Emitted when a new cosigner is set
    /// @param cosigner The address of the new cosigner
    event SetCosigner(address indexed cosigner);

    /// @notice Emitted when the expiry time for timestamps is set
    /// @param timestampExpirySeconds The number of seconds after which a timestamp is considered expired
    event SetTimestampExpirySeconds(uint256 timestampExpirySeconds);

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
    /// @dev This function should be overridden with appropriate access control
    /// @param timestampExpirySeconds The number of seconds after which a timestamp is considered expired
    function setTimestampExpirySeconds(
        uint256 timestampExpirySeconds
    ) external virtual {}

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
    function getCosignDigest(
        address minter,
        uint32 qty,
        bool waiveMintFee,
        uint256 timestamp,
        uint256 cosignNonce
    ) public view returns (bytes32) {
        CosignerStorage storage $ = _loadCosignerStorage();
        if ($.cosigner == address(0)) revert CosignerNotSet();

        return
            SignatureCheckerLib.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        address(this),
                        minter,
                        qty,
                        waiveMintFee,
                        $.cosigner,
                        timestamp,
                        block.chainid,
                        cosignNonce
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
        CosignerStorage storage $ = _loadCosignerStorage();

        if (
            SignatureCheckerLib.isValidSignatureNow(
                $.cosigner,
                getCosignDigest(minter, qty, true, timestamp, cosignNonce),
                signature
            )
        ) {
            return true;
        }

        if (
            SignatureCheckerLib.isValidSignatureNow(
                $.cosigner,
                getCosignDigest(minter, qty, false, timestamp, cosignNonce),
                signature
            )
        ) {
            return false;
        }

        revert InvalidCosignSignature();
    }

    /// @notice Gets the cosigner address
    /// @return The address of the cosigner
    function getCosigner() public view returns (address) {
        return _loadCosignerStorage().cosigner;
    }

    /// @notice Gets the expiry time for timestamps
    /// @return The number of seconds after which a timestamp is considered expired
    function getTimestampExpirySeconds() public view returns (uint256) {
        return _loadCosignerStorage().timestampExpirySeconds;
    }

    /*==============================================================
    =                       INTERNAL HELPERS                       =
    ==============================================================*/

    /// @notice Checks if a given timestamp is valid
    /// @param _timestamp The timestamp to check
    /// @dev Reverts if the timestamp has expired
    function _assertValidTimestamp(uint256 _timestamp) internal view {
        assembly {
            let expiry := sload(add(COSIGNER_STORAGE, 1))
            let isExpired := lt(_timestamp, sub(timestamp(), expiry))

            if isExpired {
                mstore(0x00, 0x26c69d1a) // TimestampExpired()
                revert(0x1c, 0x04)
            }
        }
    }

    /// @notice Sets the cosigner address
    /// @param cosigner The address of the new cosigner
    function _setCosigner(address cosigner) internal {
        assembly {
            sstore(COSIGNER_STORAGE, cosigner)
        }
        emit SetCosigner(cosigner);
    }

    /// @notice Sets the expiry time for timestamps
    /// @param timestampExpirySeconds The number of seconds after which a timestamp is considered expired
    function _setTimestampExpirySeconds(
        uint256 timestampExpirySeconds
    ) internal {
        assembly {
            sstore(add(COSIGNER_STORAGE, 1), timestampExpirySeconds)
        }
        emit SetTimestampExpirySeconds(timestampExpirySeconds);
    }

    /// @notice Loads the cosigner storage
    /// @return $ The cosigner storage
    function _loadCosignerStorage()
        internal
        pure
        returns (CosignerStorage storage $)
    {
        assembly {
            $.slot := COSIGNER_STORAGE
        }
    }
}
