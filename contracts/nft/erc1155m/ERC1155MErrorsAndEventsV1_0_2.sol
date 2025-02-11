// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ErrorsAndEvents} from "../../common/ErrorsAndEvents.sol";

interface ERC1155MErrorsAndEventsV1_0_2 is ErrorsAndEvents {
    error InvalidLimitArgsLength();
    error InvalidTokenId();

    event UpdateStage(
        uint256 indexed stage,
        uint80[] price,
        uint32[] walletLimit,
        bytes32[] merkleRoot,
        uint24[] maxStageSupply,
        uint256 startTimeUnixSeconds,
        uint256 endTimeUnixSeconds
    );
    event SetMaxMintableSupply(uint256 indexed tokenId, uint256 maxMintableSupply);
    event SetGlobalWalletLimit(uint256 indexed tokenId, uint256 globalWalletLimit);
}
