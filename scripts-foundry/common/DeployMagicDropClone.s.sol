// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC721CMInitializableV1_0_0} from "contracts/nft/erc721m/ERC721CMInitializableV1_0_0.sol";
import {ERC1155MInitializableV1_0_0} from "contracts/nft/erc1155m/ERC1155MInitializableV1_0_0.sol";
import {TokenStandard} from "contracts/common/Structs.sol";
import {MagicDropCloneFactory} from "contracts/factory/MagicDropCloneFactory.sol";

contract DeployMagicDropClone is Script {

    function run() external {
        address factoryAddress = address(uint160(vm.envUint("FACTORY_ADDRESS")));
        TokenStandard standard = parseTokenStandard(vm.envString("TOKEN_STANDARD"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        address deployedAddress;

        vm.startBroadcast(privateKey);
        // function createContract(
        //     string calldata name,
        //     string calldata symbol,
        //     TokenStandard standard,
        //     address payable initialOwner,
        //     uint32 implId
        // ) external returns (address) {
        deployedAddress = MagicDropCloneFactory(factoryAddress).createContract(
            "Test",
            "TEST",
            standard,
            payable(msg.sender),
            0
        );


        vm.stopBroadcast();

        (, string memory deployedVersion) = abi.decode(result, (string, string));
        if (keccak256(abi.encodePacked(deployedVersion)) != keccak256(abi.encodePacked(version))) {
            revert InvalidVersion(version, deployedVersion);
        }
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
