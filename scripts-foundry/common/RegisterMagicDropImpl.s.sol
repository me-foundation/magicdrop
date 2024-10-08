// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MagicDropCloneFactory} from "contracts/factory/MagicDropCloneFactory.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

contract RegisterMagicDropImpl is Script {
    function run() external {
        address registry = address(uint160(vm.envUint("REGISTRY_ADDRESS")));
        TokenStandard standard = parseTokenStandard(vm.envString("TOKEN_STANDARD"));
        address impl = address(uint160(vm.envUint("IMPL_ADDRESS")));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        MagicDropTokenImplRegistry(registry).registerImplementation(standard, impl);
        vm.stopBroadcast();

        console.log("Registered implementation standard=%s: impl=%s", standard, impl);
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