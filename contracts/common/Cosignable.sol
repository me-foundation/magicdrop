// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

abstract contract Cosignable {
    address internal _cosigner;
    uint256 internal _timestampExpirySeconds;

    event SetCosigner(address indexed cosigner);

    error CosignerNotSet();
    error InvalidCosignSignature();
    error TimestampExpired();

    // @dev: override this function with onlyOwner modifier in the contract that uses this library
    function setCosigner(address cosigner) external virtual;

    function setTimestampExpirySeconds(uint256 timestampExpirySeconds) external virtual {
        _timestampExpirySeconds = timestampExpirySeconds;
    }

    function getCosignDigest(
        address minter,
        uint32 qty,
        bool waiveMintFee,
        uint64 timestamp,
        uint256 cosignNonce
    ) public view returns (bytes32) {
        if (_cosigner == address(0)) revert CosignerNotSet();

        return
            SignatureCheckerLib.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        address(this),
                        minter,
                        qty,
                        waiveMintFee,
                        _cosigner,
                        timestamp,
                        block.chainid,
                        cosignNonce
                    )
                )
            );
    }

    function assertValidCosign(
        address minter,
        uint32 qty,
        uint64 timestamp,
        bytes memory signature,
        uint256 cosignNonce
    ) public view returns (bool) {
    
        if (
            SignatureCheckerLib.isValidSignatureNow(
                _cosigner,
                getCosignDigest(
                    minter,
                    qty,
                    true,
                    timestamp,
                    cosignNonce
                ),
                signature
            )
        ) {
            return true;
        }

        if (
            SignatureCheckerLib.isValidSignatureNow(
                _cosigner,
                getCosignDigest(
                    minter,
                    qty,
                    false,
                    timestamp,
                    cosignNonce
                ),
                signature
            )
        ) {
            return false;
        }

        revert InvalidCosignSignature();
    }

    function _assertValidTimestamp(uint64 timestamp) internal view {
        if (timestamp < block.timestamp - _timestampExpirySeconds)
            revert TimestampExpired();
    }
}
