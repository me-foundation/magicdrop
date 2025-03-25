// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

import {ERC1155MInitializableV1_0_2 as ERC1155MInitializable} from
    "../../contracts/nft/erc1155m/ERC1155MInitializableV1_0_2.sol";
import {MintStageInfo1155} from "../../contracts/common/Structs.sol";
import {ErrorsAndEvents} from "../../contracts/common/ErrorsAndEvents.sol";
import {LAUNCHPAD_MINT_FEE_RECEIVER} from "contracts/utils/Constants.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

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
    uint256 public mintFee = 0.00001 ether;

    error Unauthorized();

    function setUp() public {
        owner = address(this);
        fundReceiver = address(0x1);
        readonly = address(0x2);
        minter = address(0x4);

        vm.deal(minter, 2 ether);

        address clone = LibClone.deployERC1967(address(new ERC1155MInitializable()));
        nft = ERC1155MInitializable(clone);
        nft.initialize("Test", "TEST", owner, mintFee);

        maxMintableSupply = new uint256[](1);
        maxMintableSupply[0] = INITIAL_SUPPLY;
        globalWalletLimit = new uint256[](1);
        globalWalletLimit[0] = GLOBAL_WALLET_LIMIT;

        initialStages = new MintStageInfo1155[](0);

        nft.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );
    }

    function testSetupNonOwnerRevert() public {
        ERC1155MInitializable clone =
            ERC1155MInitializable(LibClone.deployERC1967(address(new ERC1155MInitializable())));
        clone.initialize("Test", "TEST", owner, mintFee);

        vm.startPrank(address(0x3));
        vm.expectRevert(Unauthorized.selector);
        clone.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );
        vm.stopPrank();
    }

    function testSetupLockedRevert() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsAndEvents.ContractAlreadySetup.selector);
        nft.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );

        assertEq(nft.isSetupLocked(), true);
    }

    function testInitializeRevertCalledTwice() public {
        vm.startPrank(owner);
        vm.expectRevert("Initializable: contract is already initialized");
        nft.initialize("Test", "TEST", owner, mintFee);
    }

    function testCallSetupBeforeInitializeRevert() public {
        vm.startPrank(owner);
        ERC1155MInitializable clone =
            ERC1155MInitializable(LibClone.deployERC1967(address(new ERC1155MInitializable())));
        vm.expectRevert(Unauthorized.selector);
        clone.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );
        vm.stopPrank();
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
        nft.ownerMint(minter, 0, 1);
        vm.stopPrank();

        vm.prank(minter);
        nft.safeTransferFrom(minter, readonly, 0, 1, "");

        assertEq(nft.balanceOf(minter, 0), 0);
        assertEq(nft.balanceOf(readonly, 0), 1);
    }

    function testSetTransferableRevertAlreadySet() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsAndEvents.TransferableAlreadySet.selector);
        nft.setTransferable(true);
    }

    function testMintFee() public {
        MintStageInfo1155[] memory stages = new MintStageInfo1155[](1);

        uint80[] memory price = new uint80[](1);
        price[0] = 0.5 ether;
        uint32[] memory walletLimit = new uint32[](1);
        walletLimit[0] = 1;
        bytes32[] memory merkleRoot = new bytes32[](1);
        merkleRoot[0] = bytes32(0);
        uint24[] memory maxStageSupply = new uint24[](1);
        maxStageSupply[0] = 5;

        stages[0] = MintStageInfo1155({
            price: price,
            walletLimit: walletLimit,
            merkleRoot: merkleRoot,
            maxStageSupply: maxStageSupply,
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1
        });

        nft.setStages(stages);

        vm.warp(0);
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(ErrorsAndEvents.NotEnoughValue.selector));
        nft.mint{value: 0.5 ether}(0, 1, 0, new bytes32[](0));
        assertEq(nft.balanceOf(minter, 0), 0);

        vm.prank(minter);
        nft.mint{value: 0.5 ether + mintFee}(0, 1, 1, new bytes32[](0));
        assertEq(nft.balanceOf(minter, 0), 1);

        vm.prank(owner);
        nft.withdraw();
        assertEq(fundReceiver.balance, 0.5 ether);
        assertEq(LAUNCHPAD_MINT_FEE_RECEIVER.balance, mintFee);
    }

    function testMintFeeSetter() public {
        assertEq(nft.getMintFee(), mintFee);
        vm.prank(minter);
        vm.expectRevert(Ownable.Unauthorized.selector);
        nft.setMintFee(0.00002 ether);

        vm.startPrank(owner);
        nft.setMintFee(0.00002 ether);
        assertEq(nft.getMintFee(), 0.00002 ether);
    }
}
