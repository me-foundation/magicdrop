// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../contracts/nft/erc1155m/clones/ERC1155MagicDropCloneable.sol";

contract testDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        ERC1155MagicDropCloneable erc1155blahblahblah = new ERC1155MagicDropCloneable();

        console.log(address(erc1155blahblahblah));

        vm.stopBroadcast();
    }
}
