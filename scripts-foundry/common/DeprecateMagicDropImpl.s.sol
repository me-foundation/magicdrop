// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {MagicDropTokenImplRegistry} from "contracts/registry/MagicDropTokenImplRegistry.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

contract DeprecateMagicDropImpl is Script {
    function run() external {
        address registry = address(uint160(vm.envUint("REGISTRY_ADDRESS")));
        string memory standardString = vm.envString("TOKEN_STANDARD");
        TokenStandard standard = parseTokenStandard(standardString);
        uint32 implId = uint32(vm.envUint("IMPL_ID"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        MagicDropTokenImplRegistry(registry).deprecateImplementation(standard, implId);
        vm.stopBroadcast();

        console.log("Deprecated implementation standard=%s: implId=%s", standardString, implId);
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