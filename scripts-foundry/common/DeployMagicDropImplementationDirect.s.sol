// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC721CM} from "contracts/nft/erc721m/ERC721CM.sol";
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
        string memory tokenUriSuffix = vm.envString("TOKEN_URI_SUFFIX");
        uint256 maxMintableSupply = vm.envUint("MAX_MINTABLE_SUPPLY");
        uint256 globalWalletLimit = vm.envUint("GLOBAL_WALLET_LIMIT");
        address cosigner = address(uint160(vm.envUint("COSIGNER")));
        uint256 timestampExpirySeconds = vm.envUint("TIMESTAMP_EXPIRY_SECONDS");
        address mintCurrency = address(uint160(vm.envUint("MINT_CURRENCY")));
        address fundReceiver = address(uint160(vm.envUint("FUND_RECEIVER")));
        address royaltyRecipient = address(uint160(vm.envUint("ROYALTY_RECIPIENT")));
        uint96 royaltyBps = uint96(vm.envUint("ROYALTY_BPS"));
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
                    initialOwner
                ));

                ERC721CM(deployedAddress).setDefaultRoyalty(royaltyRecipient, royaltyBps);
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