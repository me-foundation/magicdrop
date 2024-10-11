// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC721CMInitializableV1_0_0} from "contracts/nft/erc721m/ERC721CMInitializableV1_0_0.sol";
import {ERC1155MInitializableV1_0_0} from "contracts/nft/erc1155m/ERC1155MInitializableV1_0_0.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

contract DeployMagicDropImplementation is Script {
    error AddressMismatch(address expected, address actual);
    error InvalidVersion(string expected, string actual);
    error InvalidTokenStandard(string standard);
    error FailedToGetContractVersion();
    function run() external {
        TokenStandard standard = parseTokenStandard(vm.envString("TOKEN_STANDARD"));
        string memory version = vm.envString("CONTRACT_VERSION");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        address deployedAddress;

        if (standard == TokenStandard.ERC721) {
            deployedAddress = address(new ERC721CMInitializableV1_0_0());
        } else if (standard == TokenStandard.ERC1155) {
            deployedAddress = address(new ERC1155MInitializableV1_0_0());
        }

        bytes memory data = abi.encodeWithSignature("contractNameAndVersion()");
        (bool success, bytes memory result) = deployedAddress.call(data);
        if (!success) {
            revert FailedToGetContractVersion();
        }

        (, string memory deployedVersion) = abi.decode(result, (string, string));
        if (keccak256(abi.encodePacked(deployedVersion)) != keccak256(abi.encodePacked(version))) {
            revert InvalidVersion(version, deployedVersion);
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
