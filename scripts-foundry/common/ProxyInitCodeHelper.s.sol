// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

contract ProxyInitCodeHelper is Script {
    function run() external {
        address implementation = address(uint160(vm.envUint("IMPLEMENTATION")));
       
        vm.startBroadcast();
        
        bytes memory proxyInitCode = LibClone.initCodeERC1967(implementation);
        console.log("Proxy init code: %s", vm.toString(proxyInitCode));

        vm.stopBroadcast();
    }
}