// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {MagicDropTokenImplRegistry} from "contracts/registry/MagicDropTokenImplRegistry.sol";
import {MagicDropTokenImplRegistry as ZKMagicDropTokenImplRegistry} from "contracts/registry/zksync/MagicDropTokenImplRegistry.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

contract DeployMagicDropTokenImplRegistry is Script {
    error AddressMismatch();
    
    function run() external {
        bytes32 salt = vm.envBytes32("REGISTRY_SALT");
        address expectedAddress = address(uint160(vm.envUint("REGISTRY_EXPECTED_ADDRESS")));
        address initialOwner = address(uint160(vm.envUint("INITIAL_OWNER")));
        address implementationAddress = address(uint160(vm.envUint("IMPLEMENTATION")));
        bool zkSync = vm.envBool("ZK_SYNC");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        address proxy;

        if (implementationAddress != address(0)) {
            if(zkSync) {
                // No proxy for ZKsync
                return;
            } else {
                // Deploy the ERC1967 proxy
                proxy = LibClone.deployDeterministicERC1967(implementationAddress, salt);
            }

            // Initialize the proxy with the constructor arguments
            MagicDropTokenImplRegistry(proxy).initialize(initialOwner);

            if(!zkSync) {
                // Verify the deployed proxy address matches the predicted address
                if (proxy != expectedAddress) {
                    revert AddressMismatch();
                }
            }
        } else {
            if(zkSync) {
                // Deploy the zk implementation contract
                ZKMagicDropTokenImplRegistry implementation = new ZKMagicDropTokenImplRegistry{salt: salt}(initialOwner);
            } else {
                // Deploy the implementation contract
                MagicDropTokenImplRegistry implementation = new MagicDropTokenImplRegistry{salt: salt}();

                // Verify the deployed proxy address matches the predicted address
                if (address(implementation) != expectedAddress) {
                    revert AddressMismatch();
                }
            }
        }

        vm.stopBroadcast();
    }
}
