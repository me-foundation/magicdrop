// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

enum TokenStandard {
    ERC721,
    ERC1155,
    ERC20
}

struct MintStageInfo {
    uint80 price;
    uint80 mintFee;
    uint32 walletLimit; // 0 for unlimited
    bytes32 merkleRoot; // 0x0 for no presale enforced
    uint24 maxStageSupply; // 0 for unlimited
    uint256 startTimeUnixSeconds;
    uint256 endTimeUnixSeconds;
}

struct MintStageInfo1155 {
    uint80[] price;
    uint80[] mintFee;
    uint32[] walletLimit; // 0 for unlimited
    bytes32[] merkleRoot; // 0x0 for no presale enforced
    uint24[] maxStageSupply; // 0 for unlimited
    uint256 startTimeUnixSeconds;
    uint256 endTimeUnixSeconds;
}
