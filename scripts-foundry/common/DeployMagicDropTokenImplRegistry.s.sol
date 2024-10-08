// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MagicDropTokenImplRegistry} from "contracts/registry/MagicDropTokenImplRegistry.sol";

contract DeployMagicDropTokenImplRegistry is Script {
    error AddressMismatch();
    
    function run() external {
        bytes32 salt = vm.envBytes32("REGISTRY_SALT");
        address expectedAddress = address(uint160(vm.envUint("REGISTRY_EXPECTED_ADDRESS")));
        address initialOwner = address(uint160(vm.envUint("INITIAL_OWNER")));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        // Deploy the contract using CREATE2 directly
        MagicDropTokenImplRegistry registryImpl = new MagicDropTokenImplRegistry{salt: salt}();

        // Verify the deployed address matches the predicted address
        if (address(registryImpl) != expectedAddress) {
            revert AddressMismatch();
        }

        registryImpl.initialize(initialOwner);

        vm.stopBroadcast();
    }
}
