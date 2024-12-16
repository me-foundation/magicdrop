// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

import {ERC1155MInitializableV1_0_1 as ERC1155MInitializable} from
    "../../contracts/nft/erc1155m/ERC1155MInitializableV1_0_1.sol";
import {MintStageInfo1155} from "../../contracts/common/Structs.sol";
import {ErrorsAndEvents} from "../../contracts/common/ErrorsAndEvents.sol";

contract ERC1155MInitializableTest is Test {
    ERC1155MInitializable public nft;
    address public owner;
    address public minter;
    address public fundReceiver;
    address public readonly;
    uint256 public constant INITIAL_SUPPLY = 1000;
    uint256 public constant GLOBAL_WALLET_LIMIT = 0;

    uint256[] public maxMintableSupply;
    uint256[] public globalWalletLimit;
    MintStageInfo1155[] public initialStages;

    function setUp() public {
        owner = address(this);
        fundReceiver = address(0x1);
        readonly = address(0x2);
        minter = address(0x4);

        address clone = LibClone.deployERC1967(address(new ERC1155MInitializable()));
        nft = ERC1155MInitializable(clone);
        nft.initialize("Test", "TEST", owner);

        maxMintableSupply = new uint256[](1);
        maxMintableSupply[0] = INITIAL_SUPPLY;
        globalWalletLimit = new uint256[](1);
        globalWalletLimit[0] = GLOBAL_WALLET_LIMIT;

        initialStages = new MintStageInfo1155[](0);

        nft.setup(
            "base_uri_",
            maxMintableSupply,
            globalWalletLimit,
            address(0),
            fundReceiver,
            initialStages,
            address(this),
            0
        );
    }

    function testSetupLockedRevert() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsAndEvents.ContractAlreadySetup.selector);
        nft.setup(
            "base_uri_",
            maxMintableSupply,
            globalWalletLimit,
            address(0),
            fundReceiver,
            initialStages,
            address(this),
            0
        );

        assertEq(nft.isSetupLocked(), true);
    }

    function testSetTransferable() public {
        vm.startPrank(owner);
        nft.setTransferable(false);
        assertEq(nft.isTransferable(), false);

        nft.setTransferable(true);
        assertEq(nft.isTransferable(), true);
    }

    function testTransferWhenNotTransferable() public {
        vm.startPrank(owner);
        nft.setTransferable(false);
        nft.ownerMint(minter, 0, 1);
        vm.stopPrank();

        vm.expectRevert(ErrorsAndEvents.NotTransferable.selector);
        vm.prank(minter);
        nft.safeTransferFrom(minter, readonly, 0, 1, "");
    }

    function testTransferWhenTransferable() public {
        vm.startPrank(owner);
        nft.setTransferable(true);
        nft.ownerMint(minter, 0, 1);
        vm.stopPrank();

        vm.prank(minter);
        nft.safeTransferFrom(minter, readonly, 0, 1, "");

        assertEq(nft.balanceOf(minter, 0), 0);
        assertEq(nft.balanceOf(readonly, 0), 1);
    }
}
