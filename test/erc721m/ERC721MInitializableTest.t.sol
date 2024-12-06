// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";
import {Test} from "forge-std/Test.sol";
import {ERC721MInitializableV1_0_1 as ERC721MInitializable} from
    "../../contracts/nft/erc721m/ERC721MInitializableV1_0_1.sol";
import {IERC721MInitializable} from "../../contracts/nft/erc721m/interfaces/IERC721MInitializable.sol";
import {MintStageInfo} from "../../contracts/common/Structs.sol";
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
    uint256 public constant INITIAL_SUPPLY = 1000;
    uint256 public constant GLOBAL_WALLET_LIMIT = 0;

    function setUp() public {
        owner = address(this);
        fundReceiver = address(0x1);
        readonly = address(0x2);
        minter = address(0x4);

        vm.deal(owner, 10 ether);
        vm.deal(minter, 2 ether);

        address clone = LibClone.deployERC1967(address(new MockERC721M()));
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

    function testTransferWhenNotFrozen() public {
        vm.startPrank(owner);
        nft.setFrozen(false);
        nft.ownerMint(1, minter);
        vm.stopPrank();

        vm.prank(minter);
        nft.transferFrom(minter, readonly, 0);

        assertEq(nft.balanceOf(minter), 0);
        assertEq(nft.balanceOf(readonly), 1);
    }

    function testTransferWhenFrozen() public {
        vm.startPrank(owner);
        nft.setFrozen(true);
        nft.ownerMint(1, minter);
        vm.stopPrank();

        vm.expectRevert(IERC721MInitializable.TransfersAreFrozen.selector);
        vm.prank(minter);
        nft.safeTransferFrom(minter, readonly, 0);
    }

    function testBaseURISetup() public view {
        assertEq(nft.baseURI(), "base_uri_");
    }

    function testBaseURISuffixSetup() public view {
        assertEq(nft.tokenURISuffix(), ".json");
    }

    function testIsFrozen() public {
        assertEq(nft.isFrozen(), false);

        vm.startPrank(owner);
        nft.setFrozen(true);
        assertEq(nft.isFrozen(), true);
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
}
