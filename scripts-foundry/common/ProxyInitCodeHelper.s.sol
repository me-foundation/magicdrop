// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProxyInitCodeHelper is Script {
    function run() external {
        address implementation = address(uint160(vm.envUint("IMPLEMENTATION")));
        vm.startBroadcast();
        
        bytes memory proxyInitCode = LibClone.initCodeERC1967(implementation);
        // bytes memory proxyInitCode2 = abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, bytes("")));
        console.log("Proxy init code: %s", vm.toString(proxyInitCode));
        // console.log("Proxy init hash: %s", vm.toString(LibClone.initCodeHashERC1967(implementation)));
        // console.log("Proxy init code2: %s", vm.toString(proxyInitCode2));
        vm.stopBroadcast();
    }
}