// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

import {ERC1155MInitializableV1_0_1 as ERC1155MInitializable} from
    "../../contracts/nft/erc1155m/ERC1155MInitializableV1_0_1.sol";
import {MintStageInfo1155, SetupConfig} from "../../contracts/common/Structs.sol";
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

    error Unauthorized();

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
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );
    }

    function testSetupNonOwnerRevert() public {
        ERC1155MInitializable clone =
            ERC1155MInitializable(LibClone.deployERC1967(address(new ERC1155MInitializable())));
        clone.initialize("Test", "TEST", owner);

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
        nft.initialize("Test", "TEST", owner);
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

    function testGetConfig() public {
        // Setup test data
        string memory baseURI = "base_uri_";
        string memory contractURI = "contract_uri";
        address royaltyReceiver = address(0x123);
        uint96 royaltyBps = 500; // 5%
        uint256 tokenId = 0;

        // Set contract URI and royalty info
        vm.startPrank(owner);
        nft.setContractURI(contractURI);
        nft.setDefaultRoyalty(royaltyReceiver, royaltyBps);
        vm.stopPrank();

        // Get config
        SetupConfig memory config = nft.getConfig(tokenId);

        // Verify all fields match expected values
        assertEq(config.maxSupply, maxMintableSupply[tokenId]);
        assertEq(config.walletLimit, globalWalletLimit[tokenId]);
        assertEq(config.baseURI, baseURI);
        assertEq(config.contractURI, contractURI);
        assertEq(config.payoutRecipient, fundReceiver);
        assertEq(config.royaltyRecipient, royaltyReceiver);
        assertEq(config.royaltyBps, royaltyBps);

        // Verify stages array is empty (as initialized)
        assertEq(config.stages.length, 0);
    }

    function testGetConfigWithStages() public {
        uint256 tokenId = 0;

        // Create test stage
        uint80[] memory prices = new uint80[](1);
        prices[0] = 0.1 ether;
        uint80[] memory mintFees = new uint80[](1);
        mintFees[0] = 0.01 ether;
        uint32[] memory walletLimits = new uint32[](1);
        walletLimits[0] = 2;
        bytes32[] memory merkleRoots = new bytes32[](1);
        merkleRoots[0] = bytes32(0);
        uint24[] memory maxStageSupply = new uint24[](1);
        maxStageSupply[0] = 100;

        MintStageInfo1155[] memory stages = new MintStageInfo1155[](1);
        stages[0] = MintStageInfo1155({
            price: prices,
            mintFee: mintFees,
            walletLimit: walletLimits,
            merkleRoot: merkleRoots,
            maxStageSupply: maxStageSupply,
            startTimeUnixSeconds: block.timestamp,
            endTimeUnixSeconds: block.timestamp + 1 days
        });

        // Setup contract with stages
        vm.startPrank(owner);
        nft.setStages(stages);
        vm.stopPrank();

        // Get config
        SetupConfig memory config = nft.getConfig(tokenId);

        // Verify stages were set correctly
        assertEq(config.stages.length, 1);
        assertEq(config.stages[0].price, stages[0].price[tokenId]);
        assertEq(config.stages[0].mintFee, stages[0].mintFee[tokenId]);
        assertEq(config.stages[0].walletLimit, stages[0].walletLimit[tokenId]);
        assertEq(config.stages[0].merkleRoot, stages[0].merkleRoot[tokenId]);
        assertEq(config.stages[0].maxStageSupply, stages[0].maxStageSupply[tokenId]);
        assertEq(config.stages[0].startTimeUnixSeconds, stages[0].startTimeUnixSeconds);
        assertEq(config.stages[0].endTimeUnixSeconds, stages[0].endTimeUnixSeconds);
    }

    function testGetConfigMultipleTokens() public {
        // Setup multiple tokens
        uint256[] memory newMaxSupply = new uint256[](2);
        newMaxSupply[0] = 1000;
        newMaxSupply[1] = 500;

        uint256[] memory newWalletLimits = new uint256[](2);
        newWalletLimits[0] = 5;
        newWalletLimits[1] = 3;

        // Deploy new contract with multiple tokens
        address clone = LibClone.deployERC1967(address(new ERC1155MInitializable()));
        ERC1155MInitializable multiNft = ERC1155MInitializable(clone);
        multiNft.initialize("Test", "TEST", owner);

        vm.startPrank(owner);
        multiNft.setup(
            "base_uri_",
            newMaxSupply,
            newWalletLimits,
            address(0),
            fundReceiver,
            new MintStageInfo1155[](0),
            address(this),
            0
        );
        vm.stopPrank();

        // Test config for each token
        for (uint256 i = 0; i < 2; i++) {
            SetupConfig memory config = multiNft.getConfig(i);
            assertEq(config.maxSupply, newMaxSupply[i]);
            assertEq(config.walletLimit, newWalletLimits[i]);
        }
    }
}
