// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title MerkleTestHelper
 * @dev This contract builds a Merkle tree from a list of addresses, stores the root,
 *      and provides a function to retrieve a Merkle proof for a given address.
 *
 *      NOTE: Generating Merkle trees on-chain is gas-expensive, so this is typically
 *      done only in testing scenarios or for very short lists.
 */
contract MerkleTestHelper {
    address[] internal _allowedAddrs;
    bytes32 internal _root;

    /**
     * @dev Constructor that takes in an array of addresses, builds a Merkle tree, and stores the root.
     */
    constructor(address[] memory allowedAddresses) {
        // Copy addresses to storage
        for (uint256 i = 0; i < allowedAddresses.length; i++) {
            _allowedAddrs.push(allowedAddresses[i]);
        }

        // Build leaves from the addresses
        bytes32[] memory leaves = _buildLeaves(_allowedAddrs);

        // Compute merkle root
        _root = _computeMerkleRoot(leaves);
    }

    /**
     * @notice Returns the Merkle root of the addresses list.
     */
    function getRoot() external view returns (bytes32) {
        return _root;
    }

    /**
     * @notice Returns the Merkle proof for a given address.
     * @dev If the address is not found or is not part of the _allowedAddrs array,
     *      this will return an empty array.
     */
    function getProofFor(address addr) external view returns (bytes32[] memory) {
        // Find the index of the address in our stored list
        (bool isInList, uint256 index) = _findAddressIndex(addr);
        if (!isInList) {
            // Return empty proof if address doesn't exist in the allowed list
            return new bytes32[](0);
        }

        // Build leaves in memory
        bytes32[] memory leaves = _buildLeaves(_allowedAddrs);

        // Build the proof for the leaf at the found index
        return _buildProof(leaves, index);
    }

    /**
     * @dev Creates an array of leaves by double hashing each address:
     *      keccak256(bytes.concat(keccak256(abi.encodePacked(address))))
     */
    function _buildLeaves(address[] memory addrs) internal pure returns (bytes32[] memory) {
        bytes32[] memory leaves = new bytes32[](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            leaves[i] = keccak256(bytes.concat(keccak256(abi.encode(addrs[i]))));
        }
        return leaves;
    }

    /**
     * @dev Computes the Merkle root from an array of leaves.
     *      Pairs each leaf, hashing them together until only one root remains.
     *      If there is an odd number of leaves at a given level, the last leaf is "promoted" (copied up).
     */
    function _computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        require(leaves.length > 0, "No leaves to build a merkle root");

        uint256 n = leaves.length;
        while (n > 1) {
            for (uint256 i = 0; i < n / 2; i++) {
                // Sort the pair before hashing
                (bytes32 left, bytes32 right) = leaves[2 * i] < leaves[2 * i + 1] 
                    ? (leaves[2 * i], leaves[2 * i + 1])
                    : (leaves[2 * i + 1], leaves[2 * i]);
                leaves[i] = keccak256(abi.encodePacked(left, right));
            }
            // If odd, promote last leaf
            if (n % 2 == 1) {
                leaves[n / 2] = leaves[n - 1];
                n = (n / 2) + 1;
            } else {
                n = n / 2;
            }
        }

        // The first element is now the root
        return leaves[0];
    }

    /**
     * @dev Builds a Merkle proof for the leaf at the given index.
     *      We recompute the pairing tree on the fly, capturing the "sibling" each time.
     */
    function _buildProof(bytes32[] memory leaves, uint256 targetIndex)
        internal
        pure
        returns (bytes32[] memory)
    {
        bytes32[] memory proof = new bytes32[](_proofLength(leaves.length));
        uint256 proofPos = 0;
        uint256 n = leaves.length;
        uint256 index = targetIndex;

        while (n > 1) {
            bool isIndexEven = (index % 2) == 0;
            uint256 pairIndex = isIndexEven ? index + 1 : index - 1;

            if (pairIndex < n) {
                // Add the sibling to the proof without sorting
                proof[proofPos] = leaves[pairIndex];
                proofPos++;
            }

            // Move up to the next level
            for (uint256 i = 0; i < n / 2; i++) {
                // Sort pairs when building the next level
                (bytes32 left, bytes32 right) = leaves[2 * i] < leaves[2 * i + 1] 
                    ? (leaves[2 * i], leaves[2 * i + 1])
                    : (leaves[2 * i + 1], leaves[2 * i]);
                leaves[i] = keccak256(abi.encodePacked(left, right));
            }
            
            // Handle odd number of leaves
            if (n % 2 == 1) {
                leaves[n / 2] = leaves[n - 1];
                n = (n / 2) + 1;
            } else {
                n = n / 2;
            }

            index = index / 2;
        }

        // Trim unused proof elements
        uint256 trimSize = 0;
        for (uint256 i = proof.length; i > 0; i--) {
            if (proof[i - 1] != 0) {
                break;
            }
            trimSize++;
        }

        bytes32[] memory trimmedProof = new bytes32[](proof.length - trimSize);
        for (uint256 i = 0; i < trimmedProof.length; i++) {
            trimmedProof[i] = proof[i];
        }

        return trimmedProof;
    }

    /**
     * @dev Helper to find the index of a given address in the _allowedAddrs array.
     */
    function _findAddressIndex(address addr) internal view returns (bool, uint256) {
        for (uint256 i = 0; i < _allowedAddrs.length; i++) {
            if (_allowedAddrs[i] == addr) {
                return (true, i);
            }
        }
        return (false, 0);
    }

    /**
     * @dev Computes an upper bound for the proof length (worst-case).
     *      For n leaves, the maximum proof length is ~log2(n).
     *      Here we just do a simple upper bound for clarity.
     */
    function _proofLength(uint256 n) internal pure returns (uint256) {
        // If n=1, no proof. Otherwise, each tree level can contribute 1 node in the proof path.
        // A simplistic approach: log2(n) <= 256 bits for typical usage, but we do this in-line:
        uint256 count = 0;
        while (n > 1) {
            n = (n + 1) / 2; // integer division round up
            count++;
        }
        return count;
    }
}
