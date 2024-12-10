// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {LibClone} from "solady/src/utils/LibClone.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

import {ERC721MagicDropCloneable} from "contracts/nft/erc721m/clones/ERC721MagicDropCloneable.sol";
import {PublicStage, AllowlistStage, SetupConfig} from "contracts/nft/erc721m/clones/Types.sol";
import {IERC721MagicDropMetadata} from "contracts/nft/erc721m/interfaces/IERC721MagicDropMetadata.sol";

// Dummy merkle proof generation utilities for testing
contract MerkleTestHelper {
    // This is a placeholder helper. In a real test, you'd generate a real merkle tree offline.
    // Here we hardcode a single allowlisted address and its proof.
    bytes32[] internal proof;
    bytes32 internal root;
    address internal allowedAddr;

    constructor() {
        allowedAddr = address(0xABCD);
        // For simplicity, root = keccak256(abi.encodePacked(allowedAddr))
        // Proof is empty since this is a single-leaf tree.
        root = keccak256(abi.encodePacked(allowedAddr));
    }

    function getRoot() external view returns (bytes32) {
        return root;
    }

    function getProofFor(address addr) external view returns (bytes32[] memory) {
        if (addr == allowedAddr) {
            // Single-leaf tree: no proof necessary except empty array
            return new bytes32[](0);
        } else {
            // No valid proof
            bytes32[] memory emptyProof;
            return emptyProof;
        }
    }

    function getAllowedAddress() external view returns (address) {
        return allowedAddr;
    }
}

contract ERC721MagicDropCloneableTest is Test {
    ERC721MagicDropCloneable public token;
    MerkleTestHelper public merkleHelper;

    address internal owner = address(0x1234);
    address internal user = address(0x1111);
    address internal user2 = address(0x2222);
    address internal payoutRecipient = address(0x9999);
    uint256 internal initialStartTime;
    uint256 internal initialEndTime;

    function setUp() public {
        token = ERC721MagicDropCloneable(LibClone.deployERC1967(address(new ERC721MagicDropCloneable())));
        merkleHelper = new MerkleTestHelper();

        // Initialize token
        token.initialize("TestToken", "TT", owner);

        // Default stages
        initialStartTime = block.timestamp + 100;
        initialEndTime = block.timestamp + 200;

        SetupConfig memory config = SetupConfig({
            maxSupply: 1000,
            walletLimit: 5,
            baseURI: "https://example.com/metadata/",
            contractURI: "https://example.com/contract-metadata.json",
            publicStage: PublicStage({
                startTime: uint64(initialStartTime),
                endTime: uint64(initialEndTime),
                price: 0.01 ether
            }),
            allowlistStage: AllowlistStage({
                startTime: uint64(initialEndTime + 100),
                endTime: uint64(initialEndTime + 200),
                price: 0.005 ether,
                merkleRoot: merkleHelper.getRoot()
            }),
            payoutRecipient: payoutRecipient,
            provenanceHash: keccak256("some-provenance")
        });

        vm.prank(owner);
        token.setup(config);
    }

    /*==============================================================
    =                     TEST INITIALIZATION                      =
    ==============================================================*/

    function testInitialization() public {
        assertEq(token.owner(), owner);
        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TT");
        assertEq(token.payoutRecipient(), payoutRecipient);
    }

    function testMultipleInitializationReverts() public {
        vm.prank(owner);
        vm.expectRevert(); // The contract should revert if trying to re-initialize
        token.initialize("ReInit", "RI", owner);
    }

    /*==============================================================
    =                   TEST PUBLIC MINTING STAGE                  =
    ==============================================================*/

    function testMintPublicHappyPath() public {
        // Move to public sale time
        vm.warp(initialStartTime + 1);

        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(1, user);

        assertEq(token.balanceOf(user), 1);
    }

    function testMintPublicBeforeStartReverts() public {
        // Before start
        vm.warp(initialStartTime - 10);
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC721MagicDropCloneable.PublicStageNotActive.selector);
        token.mintPublic{value: 0.01 ether}(1, user);
    }

    function testMintPublicAfterEndReverts() public {
        // After end
        vm.warp(initialEndTime + 10);
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC721MagicDropCloneable.PublicStageNotActive.selector);
        token.mintPublic{value: 0.01 ether}(1, user);
    }

    function testMintPublicNotEnoughValueReverts() public {
        vm.warp(initialStartTime + 1);
        vm.deal(user, 0.005 ether);

        vm.prank(user);
        vm.expectRevert(ERC721MagicDropCloneable.NotEnoughValue.selector);
        token.mintPublic{value: 0.005 ether}(1, user);
    }

    function testMintPublicWalletLimitExceededReverts() public {
        vm.warp(initialStartTime + 1);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        // Mint up to the limit (5)
        token.mintPublic{value: 0.05 ether}(5, user);
        assertEq(token.balanceOf(user), 5);

        // Attempt to mint one more
        vm.expectRevert(ERC721MagicDropCloneable.WalletLimitExceeded.selector);
        token.mintPublic{value: 0.01 ether}(1, user);
        vm.stopPrank();
    }

    /*==============================================================
    =                  TEST ALLOWLIST MINTING STAGE                =
    ==============================================================*/

    function testMintAllowlistHappyPath() public {
        // Move time to allowlist
        uint256 allowlistStart = initialEndTime + 100;
        vm.warp(allowlistStart + 1);

        vm.deal(merkleHelper.getAllowedAddress(), 1 ether);
        vm.prank(merkleHelper.getAllowedAddress());
        token.mintAllowlist{value: 0.005 ether}(
            1, merkleHelper.getAllowedAddress(), merkleHelper.getProofFor(merkleHelper.getAllowedAddress())
        );

        assertEq(token.balanceOf(merkleHelper.getAllowedAddress()), 1);
    }

    function testMintAllowlistInvalidProofReverts() public {
        uint256 allowlistStart = initialEndTime + 100;
        vm.warp(allowlistStart + 1);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);

        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC721MagicDropCloneable.InvalidProof.selector);
        token.mintAllowlist{value: 0.005 ether}(1, user, proof);
    }

    function testMintAllowlistNotActiveReverts() public {
        // Before allowlist start
        uint256 allowlistStart = initialEndTime + 100;
        vm.warp(allowlistStart - 10);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC721MagicDropCloneable.AllowlistStageNotActive.selector);
        token.mintAllowlist{value: 0.005 ether}(1, allowedAddr, proof);
    }

    function testMintAllowlistNotEnoughValueReverts() public {
        uint256 allowlistStart = initialEndTime + 100;
        vm.warp(allowlistStart + 1);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 0.001 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC721MagicDropCloneable.NotEnoughValue.selector);
        token.mintAllowlist{value: 0.001 ether}(1, allowedAddr, proof);
    }

    function testMintAllowlistWalletLimitExceededReverts() public {
        uint256 allowlistStart = initialEndTime + 100;
        vm.warp(allowlistStart + 1);

        address allowedAddr = merkleHelper.getAllowedAddress();
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);

        vm.startPrank(allowedAddr);
        // Mint up to the limit
        token.mintAllowlist{value: 0.025 ether}(5, allowedAddr, proof);
        assertEq(token.balanceOf(allowedAddr), 5);

        vm.expectRevert(ERC721MagicDropCloneable.WalletLimitExceeded.selector);
        token.mintAllowlist{value: 0.005 ether}(1, allowedAddr, proof);
        vm.stopPrank();
    }

    /*==============================================================
    =                            BURNING                           =
    ==============================================================*/

    function testBurnHappyPath() public {
        // Public mint first
        vm.warp(initialStartTime + 1);
        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(1, user);

        uint256 tokenId = 1;
        assertEq(token.ownerOf(tokenId), user);

        vm.prank(user);
        token.burn(tokenId);

        vm.expectRevert();
        token.ownerOf(tokenId);
    }

    function testBurnInvalidTokenReverts() public {
        vm.prank(user);
        vm.expectRevert();
        token.burn(9999); // non-existent token
    }

    function testBurnNotOwnerReverts() public {
        // mint to user
        vm.warp(initialStartTime + 1);
        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(1, user);
        uint256 tokenId = 1;

        vm.prank(user2);
        vm.expectRevert();
        token.burn(tokenId);
    }

    /*==============================================================
    =                            GETTERS                           =
    ==============================================================*/

    function testGetPublicStage() public {
        PublicStage memory ps = token.getPublicStage();
        assertEq(ps.startTime, initialStartTime);
        assertEq(ps.endTime, initialEndTime);
        assertEq(ps.price, 0.01 ether);
    }

    function testGetAllowlistStage() public {
        AllowlistStage memory als = token.getAllowlistStage();
        assertEq(als.startTime, initialEndTime + 100);
        assertEq(als.endTime, initialEndTime + 200);
        assertEq(als.price, 0.005 ether);
        assertEq(als.merkleRoot, merkleHelper.getRoot());
    }

    function testPayoutRecipient() public {
        assertEq(token.payoutRecipient(), payoutRecipient);
    }

    /*==============================================================
    =                        SUPPORTSINTERFACE                     =
    ==============================================================*/

    function testSupportsInterface() public {
        // Just checks a known supported interface
        assertTrue(token.supportsInterface(type(IERC721MagicDropMetadata).interfaceId));
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
        vm.expectRevert(ERC721MagicDropCloneable.InvalidStageTime.selector);
        token.setPublicStage(invalidStage);
    }

    function testSetAllowlistStageInvalidTimesReverts() public {
        AllowlistStage memory invalidStage = AllowlistStage({
            startTime: uint64(block.timestamp + 1000),
            endTime: uint64(block.timestamp + 500), // end before start
            price: 0.005 ether,
            merkleRoot: merkleHelper.getRoot()
        });

        vm.prank(owner);
        vm.expectRevert(ERC721MagicDropCloneable.InvalidStageTime.selector);
        token.setAllowlistStage(invalidStage);
    }

    function testSetPublicStageOverlapWithAllowlistReverts() public {
        // Current allowlist starts at initialEndTime+100
        // Try to set public stage that ends after that
        PublicStage memory overlappingStage = PublicStage({
            startTime: uint64(block.timestamp + 10),
            endTime: uint64(initialEndTime + 150),
            price: 0.01 ether
        });

        vm.prank(owner);
        vm.expectRevert(ERC721MagicDropCloneable.InvalidPublicStageTime.selector);
        token.setPublicStage(overlappingStage);
    }

    function testSetAllowlistStageOverlapWithPublicReverts() public {
        // Current public ends at initialEndTime
        // Try to set allowlist that ends before public ends
        AllowlistStage memory overlappingStage = AllowlistStage({
            startTime: uint64(initialEndTime - 50),
            endTime: uint64(initialEndTime + 10),
            price: 0.005 ether,
            merkleRoot: merkleHelper.getRoot()
        });

        vm.prank(owner);
        vm.expectRevert(ERC721MagicDropCloneable.InvalidAllowlistStageTime.selector);
        token.setAllowlistStage(overlappingStage);
    }

    function testSetPayoutRecipient() public {
        vm.prank(owner);
        token.setPayoutRecipient(address(0x8888));
        assertEq(token.payoutRecipient(), address(0x8888));
    }

    function testWithdraw() public {
        // Mint some tokens to generate balance
        vm.warp(initialStartTime + 1);
        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.05 ether}(5, user); // 5 * 0.01 = 0.05 ether

        uint256 balanceBefore = payoutRecipient.balance;
        uint256 contractBal = address(token).balance;
        assertEq(contractBal, 0.05 ether);

        vm.prank(owner);
        token.withdraw();

        uint256 balanceAfter = payoutRecipient.balance;
        // Protocol fee = 5% = 0.00025 ether
        // Remaining to payout = 0.0475 ether
        assertEq(balanceAfter - balanceBefore, 0.0475 ether);
        assertEq(address(token).balance, 0);
    }

    /*==============================================================
    =                          METADATA                            =
    ==============================================================*/

    function testContractNameAndVersion() public {
        (string memory n, string memory v) = token.contractNameAndVersion();
        assertEq(n, "ERC721MagicDropCloneable");
        assertEq(v, "1.0.0");
    }

    function testTokenURI() public {
        // Mint token #1
        vm.warp(initialStartTime + 1);
        vm.deal(user, 1 ether);
        vm.prank(user);
        token.mintPublic{value: 0.01 ether}(1, user);
        string memory uri = token.tokenURI(1);
        assertEq(uri, "https://example.com/metadata/1");
    }

    function testTokenURIForNonexistentTokenReverts() public {
        vm.expectRevert();
        token.tokenURI(9999);
    }
}
