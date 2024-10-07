//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MintStageInfo1155} from "../../../common/Structs.sol";
import {ERC1155MErrorsAndEvents} from "../ERC1155MErrorsAndEvents.sol";

interface IERC1155M is ERC1155MErrorsAndEvents {
    function getNumberStages() external view returns (uint256);

    function getGlobalWalletLimit(uint256 tokenId) external view returns (uint256);

    function getMaxMintableSupply(uint256 tokenId) external view returns (uint256);

    function totalMintedByAddress(address account) external view returns (uint256[] memory);

    function getStageInfo(uint256 stage)
        external
        view
        returns (MintStageInfo1155 memory, uint256[] memory, uint256[] memory);

    function mint(
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint256 timestamp,
        bytes calldata signature
    ) external payable;

    function authorizedMint(address to, uint256 tokenId, uint32 qty, uint32 limit, bytes32[] calldata proof)
        external
        payable;
}
