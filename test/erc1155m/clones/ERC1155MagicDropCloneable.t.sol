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
import {IMagicDropMetadata} from "contracts/common/interfaces/IMagicDropMetadata.sol";

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
    address royaltyRecipient = address(0x8888);
    uint96 royaltyBps = 1000;
    uint256 mintFee = 0; // 0 ether

    uint256 internal tokenId = 1;

    SetupConfig internal config;

    function setUp() public {
        // Prepare an array of addresses for testing allowlist
        address[] memory addresses = new address[](1);
        addresses[0] = allowedAddr;
        // Deploy the new MerkleTestHelper with multiple addresses
        merkleHelper = new MerkleTestHelper(addresses);

        token = ERC1155MagicDropCloneable(LibClone.deployERC1967(address(new ERC1155MagicDropCloneable())));

        // Initialize token
        token.initialize("TestToken", "TT", owner, mintFee);

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
            payoutRecipient: payoutRecipient,
            royaltyRecipient: royaltyRecipient,
            royaltyBps: royaltyBps
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
        token.initialize("ReInit", "RI", owner, mintFee);
    }

    /*==============================================================
    =                   TEST PUBLIC MINTING STAGE                  =
    ==============================================================*/

    function testMintPublicHappyPath() public {
        // Move to public sale time
        vm.warp(publicStart + 1);

        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether + mintFee}(user, tokenId, 1, "");

        assertEq(token.balanceOf(user, tokenId), 1);
    }

    function testMintPublicBeforeStartReverts() public {
        // Before start
        vm.warp(publicStart - 10);
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.PublicStageNotActive.selector);
        token.mintPublic{value: 0.01 ether + mintFee}(user, tokenId, 1, "");
    }

    function testMintPublicAfterEndReverts() public {
        // After end
        vm.warp(publicEnd + 10);
        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.PublicStageNotActive.selector);
        token.mintPublic{value: 0.01 ether + mintFee}(user, tokenId, 1, "");
    }

    function testMintPublicNotEnoughValueReverts() public {
        vm.warp(publicStart + 1);
        vm.deal(user, 0.005 ether + mintFee);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.RequiredValueNotMet.selector);
        token.mintPublic{value: 0.005 ether + mintFee}(user, tokenId, 1, "");
    }

    function testMintPublicWalletLimitExceededReverts() public {
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        // Mint up to the limit (5)
        uint256 mintValue = (0.01 ether + mintFee) * 5;
        token.mintPublic{value: mintValue}(user, tokenId, 5, "");
        assertEq(token.balanceOf(user, tokenId), 5);

        // Attempt to mint one more
        vm.expectRevert(abi.encodeWithSelector(IERC1155MagicDropMetadata.WalletLimitExceeded.selector, tokenId));
        token.mintPublic{value: 0.01 ether + mintFee}(user, tokenId, 1, "");
        vm.stopPrank();
    }

    function testMintPublicMaxSupplyExceededReverts() public {
        vm.warp(publicStart + 1);
        uint256 mintValue = (0.01 ether + mintFee) * 1001;
        vm.deal(user, mintValue);

        vm.prank(owner);
        // unlimited wallet limit for the purpose of this test
        token.setWalletLimit(tokenId, 0);

        vm.prank(user);
        vm.expectRevert(IMagicDropMetadata.CannotExceedMaxSupply.selector);
        token.mintPublic{value: mintValue}(user, tokenId, 1001, "");
    }

    function testMintPublicOverpayReverts() public {
        vm.warp(publicStart + 1);

        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.RequiredValueNotMet.selector);
        token.mintPublic{value: 0.02 ether + mintFee}(user, tokenId, 1, "");
    }

    /*==============================================================
    =                  TEST ALLOWLIST MINTING STAGE                =
    ==============================================================*/

    function testMintAllowlistHappyPath() public {
        // Move time to allowlist
        vm.warp(allowlistStart + 1);

        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        // Generate a proof for the allowedAddr from our new MerkleTestHelper
        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);

        token.mintAllowlist{value: 0.005 ether + mintFee}(allowedAddr, tokenId, 1, proof, "");

        assertEq(token.balanceOf(allowedAddr, tokenId), 1);
    }

    function testMintAllowlistInvalidProofReverts() public {
        vm.warp(allowlistStart + 1);

        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);

        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC1155MagicDropCloneable.InvalidProof.selector);
        token.mintAllowlist{value: 0.005 ether + mintFee}(user, tokenId, 1, proof, "");
    }

    function testMintAllowlistNotActiveReverts() public {
        // Before allowlist start
        vm.warp(allowlistStart - 10);

        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC1155MagicDropCloneable.AllowlistStageNotActive.selector);
        token.mintAllowlist{value: 0.005 ether + mintFee}(allowedAddr, tokenId, 1, proof, "");
    }

    function testMintAllowlistNotEnoughValueReverts() public {
        vm.warp(allowlistStart + 1);

        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);

        vm.expectRevert(ERC1155MagicDropCloneable.RequiredValueNotMet.selector);
        token.mintAllowlist{value: 0.001 ether + mintFee}(allowedAddr, tokenId, 1, proof, "");
    }

    function testMintAllowlistWalletLimitExceededReverts() public {
        vm.warp(allowlistStart + 1);

        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);

        vm.startPrank(allowedAddr);
        // Mint up to the limit
        uint256 mintValue = (0.005 ether + mintFee) * 5;
        token.mintAllowlist{value: mintValue}(allowedAddr, tokenId, 5, proof, "");
        assertEq(token.balanceOf(allowedAddr, tokenId), 5);

        vm.expectRevert(abi.encodeWithSelector(IERC1155MagicDropMetadata.WalletLimitExceeded.selector, tokenId));
        token.mintAllowlist{value: 0.005 ether + mintFee}(allowedAddr, tokenId, 1, proof, "");
        vm.stopPrank();
    }

    function testMintAllowlistMaxSupplyExceededReverts() public {
        vm.warp(allowlistStart + 1);

        vm.prank(owner);
        // unlimited wallet limit for the purpose of this test
        token.setWalletLimit(tokenId, 0);

        uint256 mintValue = (0.005 ether + mintFee) * 1001;
        vm.deal(allowedAddr, mintValue);
        vm.prank(allowedAddr);

        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);

        vm.expectRevert(IMagicDropMetadata.CannotExceedMaxSupply.selector);
        token.mintAllowlist{value: mintValue}(allowedAddr, tokenId, 1001, proof, "");
    }

    function testMintAllowlistOverpayReverts() public {
        vm.warp(allowlistStart + 1);

        bytes32[] memory proof = merkleHelper.getProofFor(allowedAddr);
        vm.deal(allowedAddr, 1 ether);

        vm.expectRevert(ERC1155MagicDropCloneable.RequiredValueNotMet.selector);
        token.mintAllowlist{value: 0.02 ether + mintFee}(allowedAddr, tokenId, 1, proof, "");
    }

    /*==============================================================
    =                            BURNING                           =
    ==============================================================*/

    function testBurnHappyPath() public {
        // Public mint first
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether + mintFee}(user, tokenId, 1, "");

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
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.prank(user);
        token.mintPublic{value: 0.01 ether + mintFee}(user, tokenId, 1, "");

        vm.prank(user2);
        vm.expectRevert();
        token.burn(user, tokenId, 1);
    }

    function testBurnFromAuthorizedNonOwner() public {
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        token.mintPublic{value: 0.01 ether + mintFee}(user, tokenId, 1, "");
        token.setApprovalForAll(user2, true);
        vm.stopPrank();

        vm.prank(user2);
        token.burn(user, tokenId, 1);
        assertEq(token.balanceOf(user, tokenId), 0);
    }

    function testBatchBurn() public {
        vm.warp(publicStart + 1);
        vm.deal(user, 1 ether);

        vm.startPrank(user);
        uint256 mintValue = (0.01 ether + mintFee) * 5;
        token.mintPublic{value: mintValue}(user, tokenId, 5, "");
        token.setApprovalForAll(user2, true);
        vm.stopPrank();

        assertEq(token.balanceOf(user, tokenId), 5);
        assertEq(token.totalSupply(tokenId), 5);

        uint256[] memory ids = new uint256[](1);
        ids[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 2;

        vm.prank(user);
        token.batchBurn(user, ids, amounts);
        assertEq(token.balanceOf(user, tokenId), 3);
        assertEq(token.totalSupply(tokenId), 3);
        assertEq(token.totalMinted(tokenId), 5);
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

    function testGetMintFee() public {
        assertEq(token.mintFee(), mintFee);
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

    function testSetupRevertsNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        token.setup(config);
    }

    function testSetupEmptyConfigHasNoEffect() public {
        vm.prank(owner);
        token.setup(
            SetupConfig({
                tokenId: tokenId,
                maxSupply: 0,
                walletLimit: 0,
                baseURI: "",
                contractURI: "",
                allowlistStage: AllowlistStage({startTime: uint64(0), endTime: uint64(0), price: 0, merkleRoot: bytes32(0)}),
                publicStage: PublicStage({startTime: uint64(0), endTime: uint64(0), price: 0}),
                payoutRecipient: address(0),
                royaltyBps: 0,
                royaltyRecipient: address(0)
            })
        );

        // check that the config has no effect because it's using the zero values
        assertEq(token.maxSupply(tokenId), config.maxSupply);
        assertEq(token.walletLimit(tokenId), config.walletLimit);
        assertEq(token.baseURI(), config.baseURI);
        assertEq(token.contractURI(), config.contractURI);
        assertEq(token.getAllowlistStage(tokenId).startTime, config.allowlistStage.startTime);
        assertEq(token.getAllowlistStage(tokenId).endTime, config.allowlistStage.endTime);
        assertEq(token.getAllowlistStage(tokenId).price, config.allowlistStage.price);
        assertEq(token.getAllowlistStage(tokenId).merkleRoot, config.allowlistStage.merkleRoot);
        assertEq(token.getPublicStage(tokenId).startTime, config.publicStage.startTime);
        assertEq(token.getPublicStage(tokenId).endTime, config.publicStage.endTime);
        assertEq(token.getPublicStage(tokenId).price, config.publicStage.price);
        assertEq(token.payoutRecipient(), config.payoutRecipient);
        assertEq(token.royaltyAddress(), config.royaltyRecipient);
        assertEq(token.royaltyBps(), config.royaltyBps);
    }

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

        vm.deal(allowedAddr, 1 ether);
        vm.prank(allowedAddr);
        token.mintAllowlist{value: 0.005 ether}(allowedAddr, tokenId, 1, merkleHelper.getProofFor(allowedAddr), "");

        uint256 expectedProtocolFee = (0.005 ether * token.PROTOCOL_FEE_BPS()) / token.BPS_DENOMINATOR();
        uint256 expectedPayout = 0.005 ether - expectedProtocolFee;

        // Check balances after minting
        assertEq(token.PROTOCOL_FEE_RECIPIENT().balance, initialProtocolBalance + expectedProtocolFee);
        assertEq(payoutRecipient.balance, initialPayoutBalance + expectedPayout);
    }

    function testSplitProceedsPayoutRecipientZeroAddressReverts() public {
        // Move to public sale time
        vm.warp(publicStart + 1);

        vm.prank(owner);
        token.setPayoutRecipient(address(0));
        assertEq(token.payoutRecipient(), address(0));

        vm.deal(user, 1 ether);

        vm.prank(user);
        vm.expectRevert(ERC1155MagicDropCloneable.PayoutRecipientCannotBeZeroAddress.selector);
        token.mintPublic{value: 0.01 ether}(user, tokenId, 1, "");
    }

    /*==============================================================
    =                             MISC                             =
    ==============================================================*/

    function testContractNameAndVersion() public {
        (string memory name, string memory version) = token.contractNameAndVersion();
        // check that a value is returned
        assert(bytes(name).length > 0);
        assert(bytes(version).length > 0);
    }
}
