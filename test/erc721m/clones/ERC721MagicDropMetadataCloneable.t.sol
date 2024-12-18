// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Ownable} from "solady/src/auth/Ownable.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";

import {ERC721MagicDropMetadataCloneable} from "contracts/nft/erc721m/clones/ERC721MagicDropMetadataCloneable.sol";
import {IERC721MagicDropMetadata} from "contracts/nft/erc721m/interfaces/IERC721MagicDropMetadata.sol";
import {IMagicDropMetadata} from "contracts/common/interfaces/IMagicDropMetadata.sol";

interface IERC2981 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256);
}

/// @dev A testable contract that exposes a mint function for testing scenarios that depend on having minted tokens.
contract TestableERC721MagicDropMetadataCloneable is ERC721MagicDropMetadataCloneable {
    function initialize(address _owner) external initializer {
        __ERC721MagicDropMetadataCloneable__init(_owner);
    }

    function mintForTest(address to, uint256 quantity) external onlyOwner {
        _mint(to, quantity);
    }
}

contract ERC721MagicDropMetadataCloneableTest is Test {
    TestableERC721MagicDropMetadataCloneable token;

    address owner = address(0x1234);
    address user = address(0xABCD);
    address royaltyReceiver = address(0x9999);

    function setUp() public {
        token = TestableERC721MagicDropMetadataCloneable(
            LibClone.deployERC1967(address(new TestableERC721MagicDropMetadataCloneable()))
        );
        token.initialize(owner);
    }

    /*==============================================================
    =                         INITIALIZATION                       =
    ==============================================================*/

    function testInitialization() public view {
        assertEq(token.owner(), owner);
        assertEq(token.maxSupply(), 0);
        assertEq(token.walletLimit(), 0);
        assertEq(token.baseURI(), "");
        assertEq(token.contractURI(), "");
        assertEq(token.royaltyAddress(), address(0));
        assertEq(token.royaltyBps(), 0);
    }

    /*==============================================================
    =                        ONLY OWNER TESTS                      =
    ==============================================================*/

    function testOnlyOwnerFunctions() public {
        // Try calling setBaseURI as user
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setBaseURI("ipfs://newbase/");

        // Similarly test contractURI
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setContractURI("https://new-contract-uri.json");
    }

    /*==============================================================
    =                          BASE URI                            =
    ==============================================================*/

    function testSetBaseURIWhenNoTokensMinted() public {
        vm.prank(owner);
        token.setBaseURI("https://example.com/metadata/");
        assertEq(token.baseURI(), "https://example.com/metadata/");
        // No tokens minted, so no BatchMetadataUpdate event expected
    }

    function testSetBaseURIWithTokensMinted() public {
        // Mint some tokens first
        vm.startPrank(owner);
        token.mintForTest(user, 5); // now totalSupply = 5
        vm.expectEmit(true, true, true, true);
        emit IMagicDropMetadata.BatchMetadataUpdate(0, 4);
        token.setBaseURI("https://example.com/metadata/");
        vm.stopPrank();

        assertEq(token.baseURI(), "https://example.com/metadata/");
    }

    /*==============================================================
    =                         CONTRACT URI                         =
    ==============================================================*/

    function testSetContractURI() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit IMagicDropMetadata.ContractURIUpdated("https://new-contract-uri.json");
        token.setContractURI("https://new-contract-uri.json");
        assertEq(token.contractURI(), "https://new-contract-uri.json");
    }

    function testSetEmptyContractURI() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit IMagicDropMetadata.ContractURIUpdated("");
        token.setContractURI("");
        assertEq(token.contractURI(), "");
    }

    /*==============================================================
    =                          MAX SUPPLY                          =
    ==============================================================*/

    function testSetMaxSupplyBasic() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit IERC721MagicDropMetadata.MaxSupplyUpdated(1000);
        token.setMaxSupply(1000);
        assertEq(token.maxSupply(), 1000);
    }

    function testSetMaxSupplyDecreaseNotBelowMinted() public {
        vm.startPrank(owner);
        token.mintForTest(user, 10);
        // Currently minted = 10
        vm.expectRevert(IMagicDropMetadata.MaxSupplyCannotBeLessThanCurrentSupply.selector);
        token.setMaxSupply(5);

        // Setting exactly to 10 should pass
        token.setMaxSupply(10);
        assertEq(token.maxSupply(), 10);
    }

    function testSetMaxSupplyCannotIncreaseBeyondOriginal() public {
        vm.startPrank(owner);
        token.setMaxSupply(1000);
        vm.expectRevert(IMagicDropMetadata.MaxSupplyCannotBeIncreased.selector);
        token.setMaxSupply(2000);
    }

    /*==============================================================
    =                          WALLET LIMIT                        =
    ==============================================================*/

    function testSetWalletLimit() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit IERC721MagicDropMetadata.WalletLimitUpdated(20);
        token.setWalletLimit(20);
        assertEq(token.walletLimit(), 20);
    }

    function testSetZeroWalletLimit() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit IERC721MagicDropMetadata.WalletLimitUpdated(0);
        token.setWalletLimit(0);
        assertEq(token.walletLimit(), 0);
    }

    /*==============================================================
    =                         ROYALTY INFO                         =
    ==============================================================*/

    function testSetRoyaltyInfo() public {
        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit IMagicDropMetadata.RoyaltyInfoUpdated(royaltyReceiver, 500);
        token.setRoyaltyInfo(royaltyReceiver, 500);

        assertEq(token.royaltyAddress(), royaltyReceiver);
        assertEq(token.royaltyBps(), 500);

        // Check ERC2981 royaltyInfo
        (address receiver, uint256 amount) = IERC2981(address(token)).royaltyInfo(1, 10_000);
        assertEq(receiver, royaltyReceiver);
        assertEq(amount, 500); // 5% of 10000 = 500
    }

    function testSetRoyaltyInfoZeroAddress() public {
        vm.prank(owner);

        vm.expectRevert();
        token.setRoyaltyInfo(address(0), 1000);
    }

    /*==============================================================
    =                   BATCH METADATA UPDATES                     =
    ==============================================================*/

    function testEmitBatchMetadataUpdate() public {
        // Mint some tokens
        vm.startPrank(owner);
        token.mintForTest(user, 10);

        vm.expectEmit(true, true, true, true);
        emit IMagicDropMetadata.BatchMetadataUpdate(2, 5);
        token.emitBatchMetadataUpdate(2, 5);
        vm.stopPrank();
    }

    /*==============================================================
    =                         SUPPORTS INTERFACE                   =
    ==============================================================*/

    function testSupportsInterface() public view {
        // ERC2981 interfaceId = 0x2a55205a
        assertTrue(token.supportsInterface(0x2a55205a));
        // ERC4906 interfaceId = 0x49064906
        assertTrue(token.supportsInterface(0x49064906));
        // ERC721A interfaceId = 0x80ac58cd
        assertTrue(token.supportsInterface(0x80ac58cd));
        // ERC721Metadata interfaceId = 0x5b5e139f
        assertTrue(token.supportsInterface(0x5b5e139f));
        // Some random interface
        assertFalse(token.supportsInterface(0x12345678));
    }

    /*==============================================================
    =                        EDGE CASE TESTS                       =
    ==============================================================*/

    // If we never set maxSupply initially, setting it to something smaller than minted is invalid
    function testCannotSetMaxSupplyLessThanMintedEvenIfNotSetBefore() public {
        vm.startPrank(owner);
        token.mintForTest(user, 5);
        vm.expectRevert(IMagicDropMetadata.MaxSupplyCannotBeLessThanCurrentSupply.selector);
        token.setMaxSupply(1);
    }

    function testSetBaseURIEmptyString() public {
        vm.prank(owner);
        token.setBaseURI("");
        assertEq(token.baseURI(), "");
    }

    function testSetMaxSupplyToCurrentSupply() public {
        vm.startPrank(owner);
        token.mintForTest(user, 10);
        token.setMaxSupply(10);
        assertEq(token.maxSupply(), 10);
    }
}
