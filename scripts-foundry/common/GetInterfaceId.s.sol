// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ICreatorToken} from "@limitbreak/creator-token-standards/src/interfaces/ICreatorToken.sol";

contract GetInterfaceId is Script {
    function run() external {
        console.logBytes4(type(ICreatorToken).interfaceId);
    }
}
