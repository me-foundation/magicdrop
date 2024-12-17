// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {LibClone} from "solady/src/utils/LibClone.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

import {MerkleTestHelper} from "test/helpers/MerkleTestHelper.sol";

import {ERC1155MagicDropCloneable} from "contracts/nft/erc1155m/clones/ERC1155MagicDropCloneable.sol";
import {PublicStage, AllowlistStage, SetupConfig} from "contracts/nft/erc1155m/clones/Types.sol";
import {IERC1155MagicDropMetadata} from "contracts/nft/erc1155m/interfaces/IERC1155MagicDropMetadata.sol";

contract ERC1155MagicDropCloneableTest is Test {
    ERC1155MagicDropCloneable public token;
    MerkleTestHelper public merkleHelper;

    address internal owner = address(0x1234);
    address internal user = address(0x1111);
    address internal user2 = address(0x2222);
    address internal allowedAddr = address(0x3333);
    address internal payoutRecipient = address(0x9999);
    uint256 internal publicStart;
    uint256 internal publicEnd;
    uint256 internal allowlistStart;
    uint256 internal allowlistEnd;

    uint256 internal tokenId = 1;

    SetupConfig internal config;

    function setUp() public {
        token = ERC1155MagicDropCloneable(LibClone.deployERC1967(address(new ERC1155MagicDropCloneable())));
        merkleHelper = new MerkleTestHelper(allowedAddr);

        // Initialize token
        token.initialize("TestToken", "TT", owner);

        // Default stages
        allowlistStart = block.timestamp + 100;
        allowlistEnd = block.timestamp + 200;

        publicStart = block.timestamp + 300;
        publicEnd = block.timestamp + 400;

        config = SetupConfig({
            tokenId: tokenId,
            maxSupply: 1000,
            walletLimit: 5,
            baseURI: "https://example.com/metadata/",
            contractURI: "https://example.com/contract-metadata.json",
            allowlistStage: AllowlistStage({
                startTime: uint64(allowlistStart),
                endTime: uint64(allowlistEnd),
                price: 0.005 ether,
                merkleRoot: merkleHelper.getRoot()
            }),
            publicStage: PublicStage({startTime: uint64(publicStart), endTime: uint64(publicEnd), price: 0.01 ether}),
            payoutRecipient: payoutRecipient
        });

        vm.prank(owner);
        token.setup(config);
    }

    /*==============================================================
    =                    TEST INITIALIZATION / SETUP               =
    ==============================================================*/

    function testInitialization() public {
        assertEq(token.owner(), owner);
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TT");
    }

    function testReinitializeReverts() public {
        vm.prank(owner);
        vm.expectRevert(); // The contract should revert if trying to re-initialize
        token.initialize("ReInit", "RI", owner);
    }

    /*==============================================================
    =                   TEST PUBLIC MINTING STAGE                  =
    ==============================================================*/

    function testMintPublicHappyPath() public {
        // Move to public sale time
        vm.warp(publicStart + 1);

        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");

        assertEq(token.balanceOf(user, tokenId), 1);
    }

    function testMintPublicBeforeStartReverts() public {
        // Before start
        vm.warp(publicStart - 10);
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.PublicStageNotActive.selector);
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");
    }

    function testMintPublicAfterEndReverts() public {
        // After end
        vm.warp(publicEnd + 10);
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.PublicStageNotActive.selector);
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");
    }

    function testMintPublicNotEnoughValueReverts() public {
        vm.warp(publicStart + 1);
        vm.deal(user, 0.005 ether);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.NotEnoughValue.selector);
        token.mintPublic{value: 0.005 ether}(user, tokenId, 1, "");
    }

    function testMintPublicWalletLimitExceededReverts() public {
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        // Mint up to the limit (5)
        token.mintPublic{value: 0.05 ether}(user, tokenId, 5, "");
        assertEq(token.balanceOf(user, tokenId), 5);

        // Attempt to mint one more
        vm.expectRevert(abi.encodeWithSelector(IERC1155MagicDropMetadata.WalletLimitExceeded.selector, tokenId));
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");
        vm.stopPrank();
    }

    /*==============================================================
    =                  TEST ALLOWLIST MINTING STAGE                =
    ==============================================================*/

    function testMintAllowlistHappyPath() public {
        // Move time to allowlist
        vm.warp(allowlistStart + 1);

        vm.deal(merkleHelper.getAllowedAddress(), 1 ether);
        vm.prank(merkleHelper.getAllowedAddress());
        token.mintAllowlist{value: 0.005 ether}(
            merkleHelper.getAllowedAddress(), tokenId, 1, merkleHelper.getProofFor(merkleHelper.getAllowedAddress()), ""
        );

        assertEq(token.balanceOf(merkleHelper.getAllowedAddress(), tokenId), 1);
    }

    function testMintAllowlistInvalidProofReverts() public {
        vm.warp(allowlistStart + 1);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);

        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC1155MagicDropCloneable.InvalidProof.selector);
        token.mintAllowlist{value: 0.005 ether}(user, tokenId, 1, proof, "");
    }

    function testMintAllowlistNotActiveReverts() public {
        // Before allowlist start
        vm.warp(allowlistStart - 10);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC1155MagicDropCloneable.AllowlistStageNotActive.selector);
        token.mintAllowlist{value: 0.005 ether}(allowedAddr, tokenId, 1, proof, "");
    }

    function testMintAllowlistNotEnoughValueReverts() public {
        vm.warp(allowlistStart + 1);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 0.001 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC1155MagicDropCloneable.NotEnoughValue.selector);
        token.mintAllowlist{value: 0.001 ether}(allowedAddr, tokenId, 1, proof, "");
    }

    function testMintAllowlistWalletLimitExceededReverts() public {
        vm.warp(allowlistStart + 1);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);

        vm.startPrank(allowedAddr);
        // Mint up to the limit
        token.mintAllowlist{value: 0.025 ether}(allowedAddr, tokenId, 5, proof, "");
        assertEq(token.balanceOf(allowedAddr, tokenId), 5);

        vm.expectRevert(abi.encodeWithSelector(IERC1155MagicDropMetadata.WalletLimitExceeded.selector, tokenId));
        token.mintAllowlist{value: 0.005 ether}(allowedAddr, tokenId, 1, proof, "");
        vm.stopPrank();
    }

    /*==============================================================
    =                            BURNING                           =
    ==============================================================*/

    function testBurnHappyPath() public {
        // Public mint first
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");

        assertEq(token.balanceOf(user, tokenId), 1);

        vm.prank(user);
        token.burn(user, tokenId, 1);

        assertEq(token.balanceOf(user, tokenId), 0);
    }

    function testBurnInvalidTokenReverts() public {
        vm.prank(user);
        vm.expectRevert();
        token.burn(user, 9999, 1); // non-existent token
    }

    function testBurnNotOwnerReverts() public {
        // mint to user
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");

        vm.prank(user2);
        vm.expectRevert();
        token.burn(user, tokenId, 1);
    }

    /*==============================================================
    =                            GETTERS                           =
    ==============================================================*/

    function testGetPublicStage() public {
        PublicStage memory ps = token.getPublicStage(tokenId);
        assertEq(ps.startTime, publicStart);
        assertEq(ps.endTime, publicEnd);
        assertEq(ps.price, 0.01 ether);
    }

    function testGetAllowlistStage() public view {
        AllowlistStage memory als = token.getAllowlistStage(tokenId);
        assertEq(als.startTime, allowlistStart);
        assertEq(als.endTime, allowlistEnd);
        assertEq(als.price, 0.005 ether);
        assertEq(als.merkleRoot, merkleHelper.getRoot());
    }

    function testPayoutRecipient() public {
        assertEq(token.payoutRecipient(), payoutRecipient);
    }

    /*==============================================================
    =                        SUPPORTSINTERFACE                     =
    ==============================================================*/

    function testSupportsInterface() public view {
        // Just checks a known supported interface
        assertTrue(token.supportsInterface(type(IERC1155MagicDropMetadata).interfaceId));
    }

    /*==============================================================
    =                       ADMIN OPERATIONS                       =
    ==============================================================*/

    function testSetPublicStageInvalidTimesReverts() public {
        PublicStage memory invalidStage = PublicStage({
            startTime: uint64(block.timestamp + 1000),
            endTime: uint64(block.timestamp + 500), // end before start
            price: 0.01 ether
        });

        vm.prank(owner);
        vm.expectRevert(ERC1155MagicDropCloneable.InvalidStageTime.selector);
        token.setPublicStage(tokenId, invalidStage);
    }

    function testSetAllowlistStageInvalidTimesReverts() public {
        AllowlistStage memory invalidStage = AllowlistStage({
            startTime: uint64(block.timestamp + 1000),
            endTime: uint64(block.timestamp + 500), // end before start
            price: 0.005 ether,
            merkleRoot: merkleHelper.getRoot()
        });

        vm.prank(owner);
        vm.expectRevert(ERC1155MagicDropCloneable.InvalidStageTime.selector);
        token.setAllowlistStage(tokenId, invalidStage);
    }

    function testSetPublicStageOverlapWithAllowlistReverts() public {
        // Current allowlist starts at publicEnd+100
        // Try to set public stage that ends after that
        PublicStage memory overlappingStage = PublicStage({
            startTime: uint64(block.timestamp + 10),
            endTime: uint64(allowlistEnd + 150),
            price: 0.01 ether
        });

        vm.prank(owner);
        vm.expectRevert(ERC1155MagicDropCloneable.InvalidPublicStageTime.selector);
        token.setPublicStage(tokenId, overlappingStage);
    }

    function testSetAllowlistStageOverlapWithPublicReverts() public {
        // Current public ends at publicEnd
        // Try to set allowlist that ends before public ends
        AllowlistStage memory overlappingStage = AllowlistStage({
            startTime: uint64(publicEnd - 50),
            endTime: uint64(publicEnd + 10),
            price: 0.005 ether,
            merkleRoot: merkleHelper.getRoot()
        });

        vm.prank(owner);
        vm.expectRevert(ERC1155MagicDropCloneable.InvalidAllowlistStageTime.selector);
        token.setAllowlistStage(tokenId, overlappingStage);
    }

    function testSetPayoutRecipient() public {
        vm.prank(owner);
        token.setPayoutRecipient(address(0x8888));
        assertEq(token.payoutRecipient(), address(0x8888));
    }

    /*==============================================================
    =                     TEST SPLIT PROCEEDS                      =
    ==============================================================*/

    function testSplitProceeds() public {
        // Move to public sale time
        vm.warp(publicStart + 1);

        // Fund the user with enough ETH
        vm.deal(user, 1 ether);

        // Check initial balances
        uint256 initialProtocolBalance = token.PROTOCOL_FEE_RECIPIENT().balance;
        uint256 initialPayoutBalance = payoutRecipient.balance;

        // User mints a token
        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");

        // Check balances after minting
        uint256 expectedProtocolFee = (0.01 ether * token.PROTOCOL_FEE_BPS()) / token.BPS_DENOMINATOR();
        uint256 expectedPayout = 0.01 ether - expectedProtocolFee;

        assertEq(token.PROTOCOL_FEE_RECIPIENT().balance, initialProtocolBalance + expectedProtocolFee);
        assertEq(payoutRecipient.balance, initialPayoutBalance + expectedPayout);
    }

    function testSplitProceedsWithZeroPrice() public {
        // Check initial balances
        uint256 initialProtocolBalance = token.PROTOCOL_FEE_RECIPIENT().balance;
        uint256 initialPayoutBalance = payoutRecipient.balance;

        vm.prank(owner);
        token.setPublicStage(
            tokenId, PublicStage({startTime: uint64(publicStart), endTime: uint64(publicEnd), price: 0})
        );

        // Move to public sale time
        vm.warp(publicStart + 1);

        // User mints a token with price 0
        vm.prank(user);
        token.mintPublic{value: 0 ether}(user, tokenId, 1, "");

        // Check balances after minting
        assertEq(token.PROTOCOL_FEE_RECIPIENT().balance, initialProtocolBalance);
        assertEq(payoutRecipient.balance, initialPayoutBalance);
    }

    function testSplitProceedsAllowlist() public {
        // Move to allowlist time
        vm.warp(allowlistStart + 1);

        // Check initial balances
        uint256 initialProtocolBalance = token.PROTOCOL_FEE_RECIPIENT().balance;
        uint256 initialPayoutBalance = payoutRecipient.balance;

        vm.deal(merkleHelper.getAllowedAddress(), 1 ether);
        vm.prank(merkleHelper.getAllowedAddress());
        token.mintAllowlist{value: 0.005 ether}(
            merkleHelper.getAllowedAddress(), tokenId, 1, merkleHelper.getProofFor(merkleHelper.getAllowedAddress()), ""
        );

        // Check balances after minting
        uint256 expectedProtocolFee = (0.005 ether * token.PROTOCOL_FEE_BPS()) / token.BPS_DENOMINATOR();
        uint256 expectedPayout = 0.005 ether - expectedProtocolFee;

        assertEq(token.PROTOCOL_FEE_RECIPIENT().balance, initialProtocolBalance + expectedProtocolFee);
        assertEq(payoutRecipient.balance, initialPayoutBalance + expectedPayout);
    }
}
