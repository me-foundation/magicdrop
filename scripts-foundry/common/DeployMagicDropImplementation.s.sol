// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC721MInitializableV1_0_2 as ERC721MInitializable} from "contracts/nft/erc721m/ERC721MInitializableV1_0_2.sol";
import {ERC721CMInitializableV1_0_2 as ERC721CMInitializable} from "contracts/nft/erc721m/ERC721CMInitializableV1_0_2.sol";
import {ERC1155MInitializableV1_0_2 as ERC1155MInitializable} from "contracts/nft/erc1155m/ERC1155MInitializableV1_0_2.sol";
import {ERC721MagicDropCloneable} from "contracts/nft/erc721m/clones/ERC721MagicDropCloneable.sol";
import {ERC1155MagicDropCloneable} from "contracts/nft/erc1155m/clones/ERC1155MagicDropCloneable.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

enum UseCase {
    SelfServe,
    Launchpad
}
contract DeployMagicDropImplementation is Script {
    error AddressMismatch(address expected, address actual);
    error InvalidTokenStandard(string standard);

    function run() external {
        bytes32 salt = vm.envBytes32("IMPL_SALT");
        address expectedAddress = address(uint160(vm.envUint("IMPL_EXPECTED_ADDRESS")));
        TokenStandard standard = parseTokenStandard(vm.envString("TOKEN_STANDARD"));
        UseCase useCase = parseUseCase(vm.envUint("USE_CASE"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        bool royaltyEnforced = vm.envBool("ROYALTY_ENFORCED");

        vm.startBroadcast(privateKey);

        address deployedAddress;
        
        if (usecase == UseCase.Launchpad) {
            if (standard == TokenStandard.ERC721) {
                if(royaltyEnforced) {
                    deployedAddress = address(new ERC721CMInitializable{salt: salt}());
                } else {
                    deployedAddress = address(new ERC721MInitializable{salt: salt}());
                }
            } else if (standard == TokenStandard.ERC1155) {
                deployedAddress = address(new ERC1155MInitializable{salt: salt}());
            }
        } else if (useCase == UseCase.SelfServe) {
            if (standard == TokenStandard.ERC721) {
                deployedAddress = address(new ERC721MagicDropCloneable{salt: salt}());
            } else if (standard == TokenStandard.ERC1155) {
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
        if (keccak256(abi.encodePacked(useCaseString)) == keccak256(abi.encodePacked("SelfServe"))) {
            return UseCase.SelfServe;
        } else if (keccak256(abi.encodePacked(standardString)) == keccak256(abi.encodePacked("Launchpad"))) {
            return UseCase.Launchpad;
        } else {
            revert InvalidTokenStandard(standardString);
        }
    }
}
