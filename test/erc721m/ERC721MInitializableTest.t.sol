// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";
import {Test} from "forge-std/Test.sol";
import {ERC721MInitializableV1_0_1 as ERC721MInitializable} from
    "../../contracts/nft/erc721m/ERC721MInitializableV1_0_1.sol";
import {IERC721MInitializable} from "../../contracts/nft/erc721m/interfaces/IERC721MInitializable.sol";
import {MintStageInfo, SetupConfig} from "../../contracts/common/Structs.sol";
import {ErrorsAndEvents} from "../../contracts/common/ErrorsAndEvents.sol";

contract MockERC721M is ERC721MInitializable {
    function baseURI() public view returns (string memory) {
        return _currentBaseURI;
    }

    function tokenURISuffix() public view returns (string memory) {
        return _tokenURISuffix;
    }
}

contract ERC721MInitializableTest is Test {
    MockERC721M public nft;
    address public owner;
    address public minter;
    address public fundReceiver;
    address public readonly;
    address public clone;
    uint256 public constant INITIAL_SUPPLY = 1000;
    uint256 public constant GLOBAL_WALLET_LIMIT = 0;

    error Unauthorized();

    function setUp() public {
        owner = address(this);
        fundReceiver = address(0x1);
        readonly = address(0x2);
        minter = address(0x4);

        vm.deal(owner, 10 ether);
        vm.deal(minter, 2 ether);

        clone = LibClone.deployERC1967(address(new MockERC721M()));
        nft = MockERC721M(clone);
        nft.initialize("Test", "TEST", owner);
        nft.setup(
            "base_uri_",
            ".json",
            INITIAL_SUPPLY,
            GLOBAL_WALLET_LIMIT,
            address(0),
            fundReceiver,
            new MintStageInfo[](0),
            address(this),
            0
        );
    }

    function testSetupNonOwnerRevert() public {
        vm.startPrank(address(0x3));
        vm.expectRevert(Unauthorized.selector);
        nft.setup(
            "base_uri_",
            ".json",
            INITIAL_SUPPLY,
            GLOBAL_WALLET_LIMIT,
            address(0),
            fundReceiver,
            new MintStageInfo[](0),
            address(this),
            0
        );
        vm.stopPrank();
    }

    function testTransferWhenTransferable() public {
        vm.startPrank(owner);
        nft.ownerMint(1, minter);
        vm.stopPrank();

        vm.prank(minter);
        nft.transferFrom(minter, readonly, 0);

        assertEq(nft.balanceOf(minter), 0);
        assertEq(nft.balanceOf(readonly), 1);
    }

    function testTransferWhenNotTransferable() public {
        vm.startPrank(owner);
        nft.setTransferable(false);
        nft.ownerMint(1, minter);
        vm.stopPrank();

        vm.expectRevert(ErrorsAndEvents.NotTransferable.selector);
        vm.prank(minter);
        nft.safeTransferFrom(minter, readonly, 0);
    }

    function testBaseURISetup() public view {
        assertEq(nft.baseURI(), "base_uri_");
    }

    function testBaseURISuffixSetup() public view {
        assertEq(nft.tokenURISuffix(), ".json");
    }

    function testSetTransferable() public {
        vm.startPrank(owner);
        nft.setTransferable(false);
        assertEq(nft.isTransferable(), false);

        nft.setTransferable(true);
        assertEq(nft.isTransferable(), true);
    }

    function testSetTransferableRevertAlreadySet() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsAndEvents.TransferableAlreadySet.selector);
        nft.setTransferable(true);
    }

    function testSetBaseURI() public {
        vm.startPrank(owner);
        nft.setBaseURI("new_base_uri_");
        assertEq(nft.baseURI(), "new_base_uri_");
    }

    function testSetTokenURISuffix() public {
        vm.startPrank(owner);
        nft.setTokenURISuffix(".txt");
        assertEq(nft.tokenURISuffix(), ".txt");
    }

    function testSetupLockedRevert() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsAndEvents.ContractAlreadySetup.selector);
        nft.setup(
            "base_uri_",
            ".json",
            INITIAL_SUPPLY,
            GLOBAL_WALLET_LIMIT,
            address(0),
            fundReceiver,
            new MintStageInfo[](0),
            address(this),
            0
        );
    }

    function testInitializeRevertCalledTwice() public {
        vm.expectRevert(0xf92ee8a9); // InvalidInitialization()
        nft.initialize("Test", "TEST", owner);
    }

    function testCallSetupBeforeInitializeRevert() public {
        clone = LibClone.deployERC1967(address(new MockERC721M()));
        MockERC721M nft2 = MockERC721M(clone);
        vm.expectRevert(Unauthorized.selector);
        nft2.setup(
            "base_uri_",
            ".json",
            INITIAL_SUPPLY,
            GLOBAL_WALLET_LIMIT,
            address(0),
            fundReceiver,
            new MintStageInfo[](0),
            address(this),
            0
        );
    }

    function testGetConfig() public {
        // Setup test data
        string memory baseURI = "base_uri_";
        string memory contractURI = "contract_uri";
        address royaltyReceiver = address(0x123);
        uint96 royaltyBps = 500; // 5%
        
        // Set contract URI and royalty info
        vm.startPrank(owner);
        nft.setContractURI(contractURI);
        nft.setDefaultRoyalty(royaltyReceiver, royaltyBps);
        vm.stopPrank();

        // Get config
        SetupConfig memory config = nft.getConfig();

        // Verify all fields match expected values
        assertEq(config.maxSupply, INITIAL_SUPPLY);
        assertEq(config.walletLimit, GLOBAL_WALLET_LIMIT);
        assertEq(config.baseURI, baseURI);
        assertEq(config.contractURI, contractURI);
        assertEq(config.payoutRecipient, fundReceiver);
        assertEq(config.royaltyRecipient, royaltyReceiver);
        assertEq(config.royaltyBps, royaltyBps);
        
        // Verify stages array is empty (as initialized)
        assertEq(config.stages.length, 0);
    }

    function testGetConfigWithStages() public {
        // Create test stage
        MintStageInfo[] memory stages = new MintStageInfo[](1);
        stages[0] = MintStageInfo({
            price: 0.1 ether,
            mintFee: 0.01 ether,
            walletLimit: 2,
            merkleRoot: bytes32(0),
            maxStageSupply: 100,
            startTimeUnixSeconds: block.timestamp,
            endTimeUnixSeconds: block.timestamp + 1 days
        });

        // Setup contract with stages
        vm.startPrank(owner);
        nft.setStages(stages);
        vm.stopPrank();

        // Get config
        SetupConfig memory config = nft.getConfig();

        // Verify stages were set correctly
        assertEq(config.stages.length, 1);
        assertEq(config.stages[0].price, stages[0].price);
        assertEq(config.stages[0].mintFee, stages[0].mintFee);
        assertEq(config.stages[0].walletLimit, stages[0].walletLimit);
        assertEq(config.stages[0].merkleRoot, stages[0].merkleRoot);
        assertEq(config.stages[0].maxStageSupply, stages[0].maxStageSupply);
        assertEq(config.stages[0].startTimeUnixSeconds, stages[0].startTimeUnixSeconds);
        assertEq(config.stages[0].endTimeUnixSeconds, stages[0].endTimeUnixSeconds);
    }
}
