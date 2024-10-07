// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibClone} from "solady/src/utils/LibClone.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

import {IERC721A} from "erc721a/contracts/IERC721A.sol";
import {Test} from "forge-std/Test.sol";
import {ERC721CMInitializableV1_0_0 as ERC721CMInitializable} from
    "../../contracts/nft/erc721m/ERC721CMInitializableV1_0_0.sol";
import {MintStageInfo} from "../../contracts/common/Structs.sol";
import {ErrorsAndEvents} from "../../contracts/common/ErrorsAndEvents.sol";

contract ERC721CMInitializableTest is Test {
    ERC721CMInitializable public nft;
    address public owner;
    address public minter;
    address public fundReceiver;
    address public readonly;
    address public crossmintAddress;
    uint256 public constant INITIAL_SUPPLY = 1000;
    uint256 public constant GLOBAL_WALLET_LIMIT = 0;

    function setUp() public {
        owner = address(this);
        fundReceiver = address(0x1);
        readonly = address(0x2);
        crossmintAddress = address(0x3);
        minter = address(0x4);

        vm.deal(owner, 10 ether);
        vm.deal(minter, 2 ether);
        vm.deal(crossmintAddress, 1 ether);

        address clone = LibClone.deployERC1967(address(new ERC721CMInitializable()));
        nft = ERC721CMInitializable(clone);
        nft.initialize("Test", "TEST", owner);
        nft.setup(
            ".json",
            INITIAL_SUPPLY,
            GLOBAL_WALLET_LIMIT,
            address(0),
            60, // timestampExpirySeconds
            address(0),
            fundReceiver,
            crossmintAddress,
            new MintStageInfo[](0),
            address(this),
            0
        );
    }

    function testInitialState() public view {
        assertEq(nft.name(), "Test");
        assertEq(nft.symbol(), "TEST");
        assertEq(nft.owner(), owner);
        assertEq(nft.getMaxMintableSupply(), INITIAL_SUPPLY);
        assertEq(nft.getGlobalWalletLimit(), GLOBAL_WALLET_LIMIT);
        assertTrue(nft.getMintable());
    }

    function testSetMintable() public {
        nft.setMintable(false);
        assertFalse(nft.getMintable());

        vm.prank(readonly);
        vm.expectRevert(Ownable.Unauthorized.selector);
        nft.setMintable(true);
    }

    function testWithdraw() public {
        // Send 100 wei to contract address for testing
        vm.deal(address(nft), 100);
        assertEq(address(nft).balance, 100);

        uint256 initialFundReceiverBalance = fundReceiver.balance;
        nft.withdraw();
        assertEq(address(nft).balance, 0);
        assertEq(fundReceiver.balance, initialFundReceiverBalance + 100);

        vm.prank(readonly);
        vm.expectRevert(Ownable.Unauthorized.selector);
        nft.withdraw();
    }

    function testSetStages() public {
        MintStageInfo[] memory stages = new MintStageInfo[](2);
        stages[0] = MintStageInfo({
            price: 0.5 ether,
            mintFee: 0.1 ether,
            walletLimit: 3,
            merkleRoot: bytes32(uint256(1)),
            maxStageSupply: 5,
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1
        });
        stages[1] = MintStageInfo({
            price: 0.6 ether,
            mintFee: 0.1 ether,
            walletLimit: 4,
            merkleRoot: bytes32(uint256(2)),
            maxStageSupply: 10,
            startTimeUnixSeconds: 301,
            endTimeUnixSeconds: 602
        });

        nft.setStages(stages);
        assertEq(nft.getNumberStages(), 2);

        vm.prank(readonly);
        vm.expectRevert(Ownable.Unauthorized.selector);
        nft.setStages(stages);
    }

    function testMint() public {
        MintStageInfo[] memory stages = new MintStageInfo[](1);
        stages[0] = MintStageInfo({
            price: 0.5 ether,
            mintFee: 0.1 ether,
            walletLimit: 10,
            merkleRoot: bytes32(0),
            maxStageSupply: 5,
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1
        });
        nft.setStages(stages);

        vm.warp(0);
        vm.prank(minter);
        nft.mint{value: 0.6 ether}(1, 0, new bytes32[](0), 0, "");
        assertEq(nft.balanceOf(minter), 1);

        vm.expectRevert(abi.encodeWithSelector(ErrorsAndEvents.NotEnoughValue.selector));
        vm.prank(minter);
        nft.mint{value: 0.5 ether}(1, 0, new bytes32[](0), 0, "");
    }

    function testCrossmint() public {
        MintStageInfo[] memory stages = new MintStageInfo[](1);
        stages[0] = MintStageInfo({
            price: 0.5 ether,
            mintFee: 0,
            walletLimit: 0,
            merkleRoot: bytes32(0),
            maxStageSupply: 100,
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1000000
        });
        nft.setStages(stages);

        vm.warp(500000);

        vm.prank(crossmintAddress);
        nft.crossmint{value: 0.5 ether}(1, readonly, new bytes32[](0), 0, "");
        assertEq(nft.balanceOf(readonly), 1);

        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(ErrorsAndEvents.CrossmintOnly.selector));
        nft.crossmint{value: 0.5 ether}(1, readonly, new bytes32[](0), 0, "");
    }

    function testTokenURI() public {
        nft.setBaseURI("base_uri_");
        nft.setTokenURISuffix(".json");

        MintStageInfo[] memory stages = new MintStageInfo[](1);
        stages[0] = MintStageInfo({
            price: 0.1 ether,
            mintFee: 0,
            walletLimit: 0,
            merkleRoot: bytes32(0),
            maxStageSupply: 0,
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1000000
        });
        nft.setStages(stages);

        vm.warp(500000);

        vm.prank(minter);
        nft.mint{value: 0.1 ether}(1, 0, new bytes32[](0), 0, "");
        assertEq(nft.tokenURI(0), "base_uri_0.json");

        vm.expectRevert(abi.encodeWithSelector(IERC721A.URIQueryForNonexistentToken.selector));
        nft.tokenURI(1);
    }

    function testGlobalWalletLimit() public {
        nft.setGlobalWalletLimit(2);
        assertEq(nft.getGlobalWalletLimit(), 2);

        vm.expectRevert(abi.encodeWithSelector(ErrorsAndEvents.GlobalWalletLimitOverflow.selector));
        nft.setGlobalWalletLimit(INITIAL_SUPPLY + 1);
    }

    function testContractURI() public {
        string memory uri = "ipfs://bafybeidntqfipbuvdhdjosntmpxvxyse2dkyfpa635u4g6txruvt5qf7y4";
        nft.setContractURI(uri);
        assertEq(nft.contractURI(), uri);
    }
}
