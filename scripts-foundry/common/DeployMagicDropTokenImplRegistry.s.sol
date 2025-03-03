// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MagicDropTokenImplRegistry} from "contracts/registry/MagicDropTokenImplRegistry.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

contract DeployMagicDropTokenImplRegistry is Script {
    error AddressMismatch();
    
    function run() external {
        bytes32 salt = vm.envBytes32("REGISTRY_SALT");
        address expectedAddress = address(uint160(vm.envUint("REGISTRY_EXPECTED_ADDRESS")));
        address initialOwner = address(uint160(vm.envUint("INITIAL_OWNER")));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address implementationAddress = address(uint160(vm.envUint("IMPLEMENTATION")));

        vm.startBroadcast(privateKey);

        if (implementationAddress != address(0)) {
            // Deploy the ERC1967 proxy
            address proxy = LibClone.deployDeterministicERC1967(implementationAddress, salt);
            
            // Initialize the proxy with the constructor arguments
            MagicDropTokenImplRegistry(proxy).initialize(initialOwner);

            // Verify the deployed proxy address matches the predicted address
            if (proxy != expectedAddress) {
                revert AddressMismatch();
            }
        } else {
            // Deploy the implementation contract
            MagicDropTokenImplRegistry implementation = new MagicDropTokenImplRegistry{salt: salt}();

            // Verify the deployed proxy address matches the predicted address
            if (address(implementation) != expectedAddress) {
                revert AddressMismatch();
            }
        }

        vm.stopBroadcast();
    }
}
