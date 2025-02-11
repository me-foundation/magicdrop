// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ErrorsAndEvents} from "../../common/ErrorsAndEvents.sol";

interface ERC721MErrorsAndEventsV1_0_2 is ErrorsAndEvents {
    event UpdateStage(
        uint256 stage,
        uint80 price,
        uint32 walletLimit,
        bytes32 merkleRoot,
        uint24 maxStageSupply,
        uint256 startTimeUnixSeconds,
        uint256 endTimeUnixSeconds
    );

    event SetMaxMintableSupply(uint256 maxMintableSupply);
    event SetGlobalWalletLimit(uint256 globalWalletLimit);
    event SetDefaultRoyalty(address receiver, uint96 feeNumerator);
    event SetContractURI(string uri);
}
