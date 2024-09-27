// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IInitializableToken {
    function initialize(
        string calldata name,
        string calldata symbol,
        address payable initialOwner
    ) external;
}
