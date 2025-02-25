// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MagicDropTokenImplRegistry} from "contracts/registry/MagicDropTokenImplRegistry.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

contract DeployMagicDropTokenImplRegistry is Script {
    error AddressMismatch();
    
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        
        // Deploy the implementation contract
        new MagicDropTokenImplRegistry();
        
        vm.stopBroadcast();
    }
}
