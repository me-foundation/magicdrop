// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

struct MintStageInfo1155 {
    uint80[] price;
    uint32[] walletLimit; // 0 for unlimited
    bytes32[] merkleRoot; // 0x0 for no presale enforced
    uint24[] maxStageSupply; // 0 for unlimited
    uint256 startTimeUnixSeconds;
    uint256 endTimeUnixSeconds;
}
