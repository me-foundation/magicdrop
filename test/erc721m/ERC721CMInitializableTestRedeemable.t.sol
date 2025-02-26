// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {LibClone} from "solady/src/utils/LibClone.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";
import {Test} from "forge-std/Test.sol";
import {ERC721CMInitializableRedeemable} from "../../contracts/nft/erc721m/ERC721CMInitializableRedeemable.sol";
import {IERC721MInitializable} from "../../contracts/nft/erc721m/interfaces/IERC721MInitializable.sol";
import {MintStageInfo, SetupConfig} from "../../contracts/common/Structs.sol";
import {ErrorsAndEvents} from "../../contracts/common/ErrorsAndEvents.sol";

contract MockERC721CMInitializableRedeemable is
    ERC721CMInitializableRedeemable
{
    function baseURI() public view returns (string memory) {
        return _currentBaseURI;
    }

    function tokenURISuffix() public view returns (string memory) {
        return _tokenURISuffix;
    }
}

contract ERC721CMInitializableRedeemableTest is Test {
    MockERC721CMInitializableRedeemable public nft;
    address public owner;
    address public minter;
    address public redeemer;
    address public fundReceiver;
    address public readonly;
    uint256 public constant INITIAL_SUPPLY = 1000;
    uint256 public constant GLOBAL_WALLET_LIMIT = 0;
    address public clone;
    uint256 public startTime;
    uint256 public mintFee = 0.00001 ether;

    error Unauthorized();
    error NotAuthorizedRedeemer();
    error NotOwner();
    error MismatchedArrays();

    function setUp() public {
        owner = address(this);
        fundReceiver = address(0x1);
        readonly = address(0x2);
        minter = address(0x4);

        vm.deal(owner, 10 ether);
        vm.deal(minter, 2 ether);

        startTime = block.timestamp;
        MintStageInfo[] memory stages = new MintStageInfo[](1);
        stages[0] = MintStageInfo({
            price: 0.1 ether,
            walletLimit: 2,
            merkleRoot: bytes32(0),
            maxStageSupply: 100,
            startTimeUnixSeconds: startTime,
            endTimeUnixSeconds: startTime + 1 days
        });

        clone = LibClone.deployERC1967(address(new MockERC721CMInitializableRedeemable()));
        nft = MockERC721CMInitializableRedeemable(clone);
        nft.initialize("Test", "TEST", owner, mintFee);
        nft.setup(
            "base_uri_",
            ".json",
            INITIAL_SUPPLY,
            GLOBAL_WALLET_LIMIT,
            address(0),
            fundReceiver,
            stages,
            address(this),
            0
        );
    }

    // Test contract initialization and name version
    function testContractNameAndVersion() public {
        (string memory name, string memory version) = nft.contractNameAndVersion();
        assertEq(name, "ERC721CMInitializableRedeemable");
        assertEq(version, "1.0.0");
    }

    // Test adding and removing redeemer roles
    function testAddRemoveRedeemer() public {
        // Initially redeemer should not be authorized
        vm.prank(redeemer);
        vm.expectRevert(NotAuthorizedRedeemer.selector);

        address[] memory owners = new address[](1);
        owners[0] = address(0);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        nft.redeem(owners, tokenIds);

        // Add redeemer
        nft.addAuthorizedRedeemer(redeemer);

        // Mint a token to test with
        vm.prank(minter);
        nft.mint{value: 0.1 ether + mintFee}(
            1,
            1,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );

        // Now redeemer should be able to redeem
        vm.prank(redeemer);
        address[] memory validOwners = new address[](1);
        validOwners[0] = minter;
        uint256[] memory validTokenIds = new uint256[](1);
        validTokenIds[0] = 0;
        nft.redeem(validOwners, validTokenIds);

        // Token should be burned
        vm.expectRevert();
        nft.ownerOf(0);

        // Mint another token
        vm.prank(minter);
        nft.mint{value: 0.1 ether + mintFee}(
            1,
            1,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );

        // Remove redeemer
        nft.removeAuthorizedRedeemer(redeemer);

        // Redeemer should not be authorized anymore
        vm.prank(redeemer);
        vm.expectRevert(NotAuthorizedRedeemer.selector);

        address[] memory owners2 = new address[](1);
        owners2[0] = minter;
        uint256[] memory tokenIds2 = new uint256[](1);
        tokenIds2[0] = 1;
        nft.redeem(owners2, tokenIds2);
    }

    // Test redeeming batch of tokens
    function testRedeemBatch() public {
        // Add redeemer
        nft.addAuthorizedRedeemer(address(this));

        // Mint multiple tokens to minter
        vm.startPrank(minter);
        vm.deal(minter, 1 ether);
        nft.mint{value: 0.3 ether + mintFee}(
            2,
            2,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );
        vm.stopPrank();

        // Mint tokens to readonly
        vm.startPrank(readonly);
        vm.deal(readonly, 1 ether);
        nft.mint{value: 0.3 ether + mintFee}(
            2,
            2,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );
        vm.stopPrank();

        // Verify ownership
        assertEq(nft.ownerOf(0), minter);
        assertEq(nft.ownerOf(1), minter);
        assertEq(nft.ownerOf(2), readonly);
        assertEq(nft.ownerOf(3), readonly);

        // Redeem batch (mixed owners)
        address[] memory batchOwners = new address[](4);
        batchOwners[0] = minter;
        batchOwners[1] = minter;
        batchOwners[2] = readonly;
        batchOwners[3] = readonly;

        uint256[] memory batchTokenIds = new uint256[](4);
        batchTokenIds[0] = 0;
        batchTokenIds[1] = 1;
        batchTokenIds[2] = 2;
        batchTokenIds[3] = 3;

        nft.redeem(batchOwners, batchTokenIds);

        // Verify all tokens are burned
        for (uint256 i = 0; i < 4; i++) {
            vm.expectRevert();
            nft.ownerOf(i);
        }
    }

    // Test array length mismatch
    function testRedeemArrayLengthMismatch() public {
        // Add redeemer
        nft.addAuthorizedRedeemer(address(this));

        // Mint a token
        vm.prank(minter);
        vm.deal(minter, 1 ether);
        nft.mint{value: 0.1 ether + mintFee}(
            1,
            1,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );

        // Create mismatched arrays - more owners than tokenIds
        address[] memory owners = new address[](2);
        owners[0] = minter;
        owners[1] = readonly;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        // Should revert due to mismatched array lengths
        vm.expectRevert(MismatchedArrays.selector);
        nft.redeem(owners, tokenIds);

        // Create mismatched arrays - more tokenIds than owners
        address[] memory owners2 = new address[](1);
        owners2[0] = minter;

        uint256[] memory tokenIds2 = new uint256[](2);
        tokenIds2[0] = 1;
        tokenIds2[1] = 2;

        // Should revert due to mismatched array lengths
        vm.expectRevert(MismatchedArrays.selector);
        nft.redeem(owners2, tokenIds2);
    }

    // Test that only owner can add/remove redeemers
    function testOnlyOwnerCanManageRedeemers() public {
        // Try to add redeemer as non-owner
        vm.prank(minter);
        vm.expectRevert();
        nft.addAuthorizedRedeemer(redeemer);

        // Add redeemer as owner
        nft.addAuthorizedRedeemer(redeemer);

        // Try to remove redeemer as non-owner
        vm.prank(minter);
        vm.expectRevert();
        nft.removeAuthorizedRedeemer(redeemer);

        // Remove redeemer as owner
        nft.removeAuthorizedRedeemer(redeemer);
    }

    // Test redeeming non-existent token
    function testRedeemNonExistentToken() public {
        // Add redeemer
        nft.addAuthorizedRedeemer(address(this));

        // Try to redeem non-existent token
        address[] memory owners = new address[](1);
        owners[0] = minter;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 999; // This token doesn't exist

        vm.expectRevert();
        nft.redeem(owners, tokenIds);
    }

    // Test existing functionality from the original test file
    function testRedeemHappyPath() public {
        // Setup authorized redeemer
        nft.addAuthorizedRedeemer(address(this));

        // Mint tokens to multiple addresses
        address[] memory owners = new address[](2);
        owners[0] = minter;
        owners[1] = readonly;

        vm.deal(minter, 1 ether);
        vm.deal(readonly, 1 ether);

        vm.prank(minter);
        nft.mint{value: 0.1 ether + mintFee}(
            1,
            1,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );

        vm.prank(readonly);
        nft.mint{value: 0.1 ether + mintFee}(
            1,
            1,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        // Verify initial ownership
        assertEq(nft.ownerOf(0), minter);
        assertEq(nft.ownerOf(1), readonly);

        // Redeem tokens
        nft.redeem(owners, tokenIds);

        // Verify tokens are burned
        vm.expectRevert();
        nft.ownerOf(0);
        vm.expectRevert();
        nft.ownerOf(1);
    }

    function testRedeemNotOwnerReverts() public {
        // Setup authorized redeemer
        nft.addAuthorizedRedeemer(address(this));

        // Mint token
        vm.deal(minter, 1 ether);
        vm.prank(minter);
        nft.mint{value: 0.1 ether + mintFee}(
            1,
            1,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );

        // Try to redeem with wrong owner
        address[] memory owners = new address[](1);
        owners[0] = readonly; // Wrong owner

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.expectRevert(NotOwner.selector);
        nft.redeem(owners, tokenIds);
    }

    function testRedeemNotAuthorizedRedeemerReverts() public {
        // Mint token
        vm.deal(minter, 1 ether);
        vm.prank(minter);
        nft.mint{value: 0.1 ether + mintFee}(
            1,
            1,
            new bytes32[](0),
            block.timestamp,
            new bytes(0)
        );

        address[] memory owners = new address[](1);
        owners[0] = minter;

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        // Try to redeem without being authorized redeemer
        vm.prank(readonly);
        vm.expectRevert(NotAuthorizedRedeemer.selector);
        nft.redeem(owners, tokenIds);
    }
}