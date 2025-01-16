// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Script.sol";
import "../../test/helpers/MerkleTestHelper.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

contract MerkleTreeScript is Script {
    function run() external {
        // Define a list of addresses
        address[] memory addresses = new address[](3);
        addresses[0] = 0x68715f1d1bdbbc620488a55AD0a8C382dECFf15d;
        addresses[1] = 0xB8AE94284e4EFfAD15E825BC1437e8699E447544;
        addresses[2] = 0x366f043D5d1e4ff706C5656f3a4Cc89694c07318;

        // Deploy the MerkleTestHelper contract with the addresses
        MerkleTestHelper merkleHelper = new MerkleTestHelper(addresses);

        // Log the Merkle root
        bytes32 root = merkleHelper.getRoot();
        console.log("Merkle Root:");
        console.logBytes32(root);

        // Choose an address to get the proof for
        address targetAddress = addresses[0];
        console.log("\nTarget Address:");
        console.log(targetAddress);
        
        // Log the leaf hash for the target address
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(targetAddress))));
        console.log("\nLeaf Hash:");
        console.logBytes32(leaf);

        // Log the Merkle proof for the chosen address
        bytes32[] memory proof = merkleHelper.getProofFor(targetAddress);
        console.log("\nProof Elements:");
        for (uint256 i = 0; i < proof.length; i++) {
            console.logBytes32(proof[i]);
        }

        // Verify the proof using MerkleProofLib
        bool isValid = MerkleProofLib.verify(proof, root, leaf);
        console.log("\nProof is valid:", isValid);
    }
}