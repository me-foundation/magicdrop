// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ErrorsAndEvents} from "../../common/ErrorsAndEvents.sol";

interface ERC1155MErrorsAndEvents is ErrorsAndEvents {
    error InvalidLimitArgsLength();
    error InvalidTokenId();

    event UpdateStage(
        uint256 indexed stage,
        uint80[] price,
        uint80[] mintFee,
        uint32[] walletLimit,
        bytes32[] merkleRoot,
        uint24[] maxStageSupply,
        uint64 startTimeUnixSeconds,
        uint64 endTimeUnixSeconds
    );
    event SetMaxMintableSupply(uint256 indexed tokenId, uint256 maxMintableSupply);
    event SetGlobalWalletLimit(uint256 indexed tokenId, uint256 globalWalletLimit);
    event SetTransferable(bool transferable);
    event DefaultRoyaltySet(address receiver, uint96 feeNumerator);
    event TokenRoyaltySet(uint256 indexed tokenId, address receiver, uint96 feeNumerator);
}