// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC721MInitializableV1_0_2} from "contracts/nft/erc721m/ERC721MInitializableV1_0_2.sol";
import {ERC721CMInitializableV1_0_2} from "contracts/nft/erc721m/ERC721CMInitializableV1_0_2.sol";
import {ERC1155MInitializableV1_0_2} from "contracts/nft/erc1155m/ERC1155MInitializableV1_0_2.sol";
import {ERC721MagicDropCloneable} from "contracts/nft/erc721m/clones/ERC721MagicDropCloneable.sol";
import {ERC1155MagicDropCloneable} from "contracts/nft/erc1155m/clones/ERC1155MagicDropCloneable.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

contract DeployMagicDropImplementation is Script {
    error AddressMismatch(address expected, address actual);
    error InvalidTokenStandard(string standard);

    enum UseCase {
        Launchpad,
        SelfServe
    }

    function run() external {
        bytes32 salt = vm.envBytes32("IMPL_SALT");
        address expectedAddress = address(uint160(vm.envUint("IMPL_EXPECTED_ADDRESS")));
        TokenStandard standard = parseTokenStandard(vm.envString("TOKEN_STANDARD"));
        bool isERC721C = vm.envBool("IS_ERC721C");
        UseCase useCase = parseUseCase(vm.envString("USE_CASE"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        address deployedAddress;

        if (standard == TokenStandard.ERC721) {
            if (useCase == UseCase.Launchpad) {
                if(isERC721C) {
                    deployedAddress = address(new ERC721CMInitializableV1_0_2{salt: salt}());
                } else {
                     deployedAddress = address(new ERC721MInitializableV1_0_2{salt: salt}());
                }
            } else if(useCase == UseCase.SelfServe) {
                deployedAddress = address(new ERC721MagicDropCloneable{salt: salt}());
            }
        } else if (standard == TokenStandard.ERC1155) {
            if(useCase == UseCase.Launchpad) {
                deployedAddress = address(new ERC1155MInitializableV1_0_2{salt: salt}());
            } else if(useCase == UseCase.SelfServe) {
                deployedAddress = address(new ERC1155MagicDropCloneable{salt: salt}());
            }
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

    function parseUseCase(string memory useCaseString) internal pure returns (UseCase) {
        if (keccak256(abi.encodePacked(useCaseString)) == keccak256(abi.encodePacked("launchpad"))) {
            return UseCase.Launchpad;
        } else if (keccak256(abi.encodePacked(useCaseString)) == keccak256(abi.encodePacked("self-serve"))) {
            return UseCase.SelfServe;
        } else {
            revert InvalidTokenStandard(useCaseString);
        }
    }
}
