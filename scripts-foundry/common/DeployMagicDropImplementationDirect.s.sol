// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC721M} from "contracts/nft/erc721m/ERC721M.sol";
import {ERC721CM} from "contracts/nft/erc721m/ERC721CM.sol";
import {ERC1155M} from "contracts/nft/erc1155m/ERC1155M.sol";
import {TokenStandard} from "contracts/common/Structs.sol";

contract DeployMagicDropImplementationDirect is Script {
    error AddressMismatch(address expected, address actual);
    error InvalidTokenStandard(string standard);
    error NotImplementedYet();

    function run() external {
        bytes32 salt = vm.envBytes32("IMPL_SALT");
        address expectedAddress = address(uint160(vm.envUint("IMPL_EXPECTED_ADDRESS")));
        TokenStandard standard = parseTokenStandard(vm.envString("TOKEN_STANDARD"));
        bool isERC721C = vm.envBool("IS_ERC721C");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory name = vm.envString("NAME");
        string memory symbol = vm.envString("SYMBOL");
        string memory tokenUriSuffix = "";
        uint256 maxMintableSupply = 1000;
        uint256 globalWalletLimit = 0;
        address cosigner = address(0);
        uint256 timestampExpirySeconds = 60;
        address mintCurrency = address(0);
        address fundReceiver = address(uint160(vm.envUint("FUND_RECEIVER")));
        uint256 mintFee = vm.envUint("MINT_FEE");
        address initialOwner = address(uint160(vm.envUint("INITIAL_OWNER")));

        vm.startBroadcast(privateKey);

        address deployedAddress;

        if (standard == TokenStandard.ERC721) {
            if (isERC721C) {
                deployedAddress = address(new ERC721CM{salt: salt}(
                    name,
                    symbol,
                    tokenUriSuffix,
                    maxMintableSupply,
                    globalWalletLimit,
                    cosigner,
                    timestampExpirySeconds,
                    mintCurrency,
                    fundReceiver,
                    mintFee,
                    initialOwner
                ));
            } else {
                revert NotImplementedYet();
            }
        } else if (standard == TokenStandard.ERC1155) {
            revert NotImplementedYet();
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
