// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {IOperatorFilterRegistry} from "operator-filter-registry/src/IOperatorFilterRegistry.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CANONICAL_OPERATOR_FILTER_REGISTRY_ADDRESS} from "../utils/Constants.sol";
/**
 * @title  OwnedRegistrant
 * @notice Ownable contract that registers itself with the OperatorFilterRegistry and administers its own entries,
 *         to facilitate a subscription whose ownership can be transferred.
 */

contract OwnedRegistrant is Ownable2Step {
    /// @dev The constructor that is called when the contract is being deployed.
    constructor(address _owner) Ownable(msg.sender) {
        IOperatorFilterRegistry(CANONICAL_OPERATOR_FILTER_REGISTRY_ADDRESS)
            .register(address(this));
        transferOwnership(_owner);
    }
}
