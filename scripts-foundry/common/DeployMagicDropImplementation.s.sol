// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC721MInitializableV1_0_1 as ERC721MInitializable} from "contracts/nft/erc721m/ERC721MInitializableV1_0_1.sol";
import {ERC1155MInitializableV1_0_1 as ERC1155MInitializable} from "contracts/nft/erc1155m/ERC1155MInitializableV1_0_1.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

contract DeployMagicDropImplementation is Script {
    error AddressMismatch(address expected, address actual);
    error InvalidTokenStandard(string standard);

    function run() external {
        bytes32 salt = vm.envBytes32("IMPL_SALT");
        address expectedAddress = address(uint160(vm.envUint("IMPL_EXPECTED_ADDRESS")));
        TokenStandard standard = parseTokenStandard(vm.envString("TOKEN_STANDARD"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        address deployedAddress;

        if (standard == TokenStandard.ERC721) {
            deployedAddress = address(new ERC721MInitializable{salt: salt}());
        } else if (standard == TokenStandard.ERC1155) {
            deployedAddress = address(new ERC1155MInitializable{salt: salt}());
        }

        if (address(deployedAddress) != expectedAddress) {
            revert AddressMismatch(expectedAddress, deployedAddress);
        }

        vm.stopBroadcast();
    }

    function parseTokenStandard(string memory standardString) internal pure returns (TokenStandard) {
        if (keccak256(abi.encodePacked(standardString)) == keccak256(abi.encodePacked("ERC721"))) {
            return TokenStandard.ERC721;
        } else if (keccak256(abi.encodePacked(standardString)) == keccak256(abi.encodePacked("ERC1155"))) {
            return TokenStandard.ERC1155;
        } else {
            revert InvalidTokenStandard(standardString);
        }
    }
}
