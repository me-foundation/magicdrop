// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MagicDropTokenImplRegistry} from "contracts/registry/MagicDropTokenImplRegistry.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

contract RegisterMagicDropImpl is Script {
    function run() external {
        address registry = address(uint160(vm.envUint("REGISTRY_ADDRESS")));
        string memory standardString = vm.envString("TOKEN_STANDARD");
        TokenStandard standard = parseTokenStandard(standardString);
        address impl = address(uint160(vm.envUint("IMPL_ADDRESS")));
        bool isDefault = vm.envBool("IS_DEFAULT");
        uint256 fee = vm.envUint("FEE");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        MagicDropTokenImplRegistry(registry).registerImplementation(standard, impl, isDefault, fee);
        vm.stopBroadcast();

        console.log("Registered implementation standard=%s: impl=%s", standardString, impl);
    }

    function parseTokenStandard(string memory standardString) internal pure returns (TokenStandard) {
        if (keccak256(abi.encodePacked(standardString)) == keccak256(abi.encodePacked("ERC721"))) {
            return TokenStandard.ERC721;
        } else if (keccak256(abi.encodePacked(standardString)) == keccak256(abi.encodePacked("ERC1155"))) {
            return TokenStandard.ERC1155;
        } else {
            revert("Invalid TokenStandard");
        }
    }
}