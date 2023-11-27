// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/creator-token-standards/utils/TransferPolicy.sol";

interface ITransferValidator {
    function applyCollectionTransferPolicy(address caller, address from, address to) external view;
}