//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "erc721a-upgradeable/contracts/extensions/IERC721AQueryableUpgradeable.sol";
import "../../../common/Structs.sol";
import {ERC721MErrorsAndEvents} from "../ERC721MErrorsAndEvents.sol";

/**
 * @title IERC721MInitializable
 * @dev This contract is not meant for use in Upgradeable Proxy contracts though it may base on Upgradeable contract. The purpose of this
 * contract is for use with EIP-1167 Minimal Proxies (Clones).
 */
interface IERC721MInitializable is IERC721AQueryableUpgradeable, ERC721MErrorsAndEvents {
    function getNumberStages() external view returns (uint256);

    function getGlobalWalletLimit() external view returns (uint256);

    function getMaxMintableSupply() external view returns (uint256);

    function totalMintedByAddress(address a) external view returns (uint256);

    function getStageInfo(uint256 index) external view returns (MintStageInfo memory, uint32, uint256);

    function mint(uint32 qty, uint32 limit, bytes32[] calldata proof, uint256 timestamp, bytes calldata signature)
        external
        payable;

    function authorizedMint(
        uint32 qty,
        address to,
        uint32 limit,
        bytes32[] calldata proof,
        uint256 timestamp,
        bytes calldata signature
    ) external payable;
}
