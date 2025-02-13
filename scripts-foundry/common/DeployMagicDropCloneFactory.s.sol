// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {MagicDropCloneFactory} from "contracts/factory/MagicDropCloneFactory.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

contract DeployMagicDropCloneFactory is Script {
    error AddressMismatch();

    function run() external {
        bytes32 salt = vm.envBytes32("FACTORY_SALT");
        address expectedAddress = address(uint160(vm.envUint("FACTORY_EXPECTED_ADDRESS")));
        address initialOwner = address(uint160(vm.envUint("INITIAL_OWNER")));
        address registry = address(uint160(vm.envUint("REGISTRY_ADDRESS")));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        
        // Deploy the implementation contract
        MagicDropCloneFactory implementation = new MagicDropCloneFactory();
        
        // Deploy the ERC1967 proxy
        address proxy = LibClone.deployDeterministicERC1967(address(implementation), salt);

        // Initialize the proxy with the constructor arguments
        MagicDropCloneFactory(proxy).initialize(initialOwner, registry);

        // Verify the deployed proxy address matches the predicted address
        if (proxy != expectedAddress) {
            revert AddressMismatch();
        }

        vm.stopBroadcast();
    }
}
