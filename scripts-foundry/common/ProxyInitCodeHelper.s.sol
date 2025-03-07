// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {ERC1967Factory} from "solady/src/utils/ext/zksync/ERC1967Factory.sol";

contract ProxyInitCodeHelper is Script {
    function run() external {
        address implementation = address(uint160(vm.envUint("IMPLEMENTATION")));
        bool zkSync = vm.envBool("ZK_SYNC");
       
        vm.startBroadcast();

        address ZK_PROXY_FACTORY_ADDRESS = 0xc4151FeCa42Df507F158D1FBC4Eb5C145D9CE16B;

        bytes memory proxyInitCode;
        if(zkSync) {
            proxyInitCode = ERC1967Factory(ZK_PROXY_FACTORY_ADDRESS)._extcodehash(implementationAddress);
        } else {
            proxyInitCode = LibClone.initCodeERC1967(implementation);
        }
        
        console.log("Proxy init code: %s", vm.toString(proxyInitCode));

        vm.stopBroadcast();
    }
}