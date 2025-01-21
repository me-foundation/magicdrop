// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {Cosignable} from "../../contracts/common/Cosignable.sol";

contract MockCosignable is Cosignable {
    constructor(address cosigner) {
        _setCosigner(cosigner);
    }

    function setCosigner(address cosigner) external override {
        _setCosigner(cosigner);
    }

    // Expose internal functions for testing
    function exposedAssertValidTimestamp(uint256 timestamp) public view {
        _assertValidTimestamp(timestamp);
    }

    function setTimestampExpirySeconds(uint256 timestampExpirySeconds) external override {
        _setTimestampExpirySeconds(timestampExpirySeconds);
    }
}

contract CosignableTest is Test {
    MockCosignable public cosignable;
    address public cosigner;
    uint256 private cosignerPrivateKey;

    function setUp() public {
        cosignerPrivateKey = 0x1234;
        cosigner = vm.addr(cosignerPrivateKey);
        cosignable = new MockCosignable(cosigner);
    }

    function testSetCosigner() public {
        address newCosigner = address(0x2);
        cosignable.setCosigner(newCosigner);
        assertEq(cosignable.getCosigner(), newCosigner);
    }

    function testSetTimestampExpirySeconds() public {
        uint256 newExpirySeconds = 3600;
        cosignable.setTimestampExpirySeconds(newExpirySeconds);
        assertEq(cosignable.getTimestampExpirySeconds(), newExpirySeconds);
    }

    function testGetCosignDigest() public view {
        address minter = address(0x3);
        uint32 qty = 5;
        bool waiveMintFee = true;
        uint256 timestamp = block.timestamp;
        uint256 cosignNonce = 1;

        bytes32 digest = cosignable.getCosignDigest(minter, qty, waiveMintFee, timestamp, cosignNonce);
        assertTrue(digest != bytes32(0));
    }

    function testFuzzAssertValidCosign(address minter, uint32 qty, uint256 timestamp, uint256 cosignNonce)
        public
        view
    {
        // Ensure timestamp is within a reasonable range
        timestamp = bound(timestamp, block.timestamp, block.timestamp + 365 days);

        bytes32 digest = cosignable.getCosignDigest(minter, qty, true, timestamp, cosignNonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(cosignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool valid = cosignable.assertValidCosign(minter, qty, timestamp, signature, cosignNonce);
        assertTrue(valid);
    }

    function testAssertValidCosignFalse() public view {
        address minter = address(0x3);
        uint32 qty = 5;
        uint256 timestamp = block.timestamp;
        uint256 cosignNonce = 1;

        bytes32 digest = cosignable.getCosignDigest(minter, qty, false, timestamp, cosignNonce);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(cosignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bool valid = cosignable.assertValidCosign(minter, qty, timestamp, signature, cosignNonce);
        assertFalse(valid);
    }

    function testAssertValidCosignInvalidSignature() public {
        address minter = address(0x3);
        uint32 qty = 5;
        uint256 timestamp = block.timestamp;
        uint256 cosignNonce = 1;

        bytes memory invalidSignature = new bytes(65);

        vm.expectRevert(Cosignable.InvalidCosignSignature.selector);
        cosignable.assertValidCosign(minter, qty, timestamp, invalidSignature, cosignNonce);
    }

    function testAssertValidTimestamp() public {
        vm.warp(69420);

        uint256 expirySeconds = 3600;
        cosignable.setTimestampExpirySeconds(expirySeconds);

        uint256 validTimestamp = block.timestamp - expirySeconds + 1;
        cosignable.exposedAssertValidTimestamp(validTimestamp);

        uint256 expiredTimestamp = block.timestamp - expirySeconds - 1;
        vm.expectRevert(Cosignable.TimestampExpired.selector);
        cosignable.exposedAssertValidTimestamp(expiredTimestamp);
    }

    function testCosignerNotSet() public {
        MockCosignable newCosignable = new MockCosignable(address(0));

        vm.expectRevert(Cosignable.CosignerNotSet.selector);
        newCosignable.getCosignDigest(address(0x3), 5, true, block.timestamp, 1);
    }
}
