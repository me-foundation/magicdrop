// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// Dummy merkle proof generation utilities for testing
contract MerkleTestHelper {
    // This is a placeholder helper. In a real test, you'd generate a real merkle tree offline.
    // Here we hardcode a single allowlisted address and its proof.
    bytes32[] internal _proof;
    bytes32 internal _root;
    address internal _allowedAddr;

    constructor(address allowedAddr) {
        _allowedAddr = allowedAddr;
        // For simplicity, root = keccak256(abi.encodePacked(_allowedAddr))
        // Proof is empty since this is a single-leaf tree.
        _root = keccak256(abi.encodePacked(_allowedAddr));
    }

    function getRoot() external view returns (bytes32) {
        return _root;
    }

    function getProofFor(address addr) external view returns (bytes32[] memory) {
        if (addr == _allowedAddr) {
            // Single-leaf tree: no proof necessary except empty array
            return new bytes32[](0);
        } else {
            // No valid proof
            bytes32[] memory emptyProof;
            return emptyProof;
        }
    }

    function getAllowedAddress() external view returns (address) {
        return _allowedAddr;
    }
}
