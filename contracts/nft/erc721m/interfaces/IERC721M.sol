//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MintStageInfo} from "../../../common/Structs.sol";
import "erc721a/contracts/extensions/IERC721AQueryable.sol";
import {ERC721MErrorsAndEvents} from "../ERC721MErrorsAndEvents.sol";

interface IERC721M is IERC721AQueryable, ERC721MErrorsAndEvents {
    function getNumberStages() external view returns (uint256);

    function getGlobalWalletLimit() external view returns (uint256);

    function getMaxMintableSupply() external view returns (uint256);

    function totalMintedByAddress(address a) external view returns (uint256);

    function getStageInfo(
        uint256 index
    ) external view returns (MintStageInfo memory, uint32, uint256);

    function mint(
        uint32 qty,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable;

    function mintWithLimit(
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable;

    function crossmint(
        uint32 qty,
        address to,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable;

    function authorizedMint(
        uint32 qty,
        address to,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable;
}
