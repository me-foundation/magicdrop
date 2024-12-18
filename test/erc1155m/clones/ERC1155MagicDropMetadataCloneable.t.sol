// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {ERC1155} from "solady/src/tokens/ERC1155.sol";

import {Ownable} from "solady/src/auth/Ownable.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";

import {IMagicDropMetadata} from "contracts/common/interfaces/IMagicDropMetadata.sol";
import {IERC1155MagicDropMetadata} from "contracts/nft/erc1155m/interfaces/IERC1155MagicDropMetadata.sol";
import {ERC1155MagicDropMetadataCloneable} from "contracts/nft/erc1155m/clones/ERC1155MagicDropMetadataCloneable.sol";

interface IERC2981 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256);
}

/// @dev A testable contract that exposes a mint function for testing scenarios that depend on having minted tokens.
contract TestableERC1155MagicDropMetadataCloneable is ERC1155MagicDropMetadataCloneable {
    bool private _initialized;

    function initialize(string memory name_, string memory symbol_, address owner_) external initializer {
        __ERC1155MagicDropMetadataCloneable__init(name_, symbol_, owner_);
        _initialized = true;
    }

    function mintForTest(address to, uint256 tokenId, uint256 quantity) external onlyOwner {
        _totalMintedByUserPerToken[to][tokenId] += quantity;
        _tokenSupply[tokenId].totalMinted += uint64(quantity);
        _tokenSupply[tokenId].totalSupply += uint64(quantity);

        _mint(to, tokenId, quantity, "");
    }
}

contract ERC1155MagicDropMetadataCloneableTest is Test {
    TestableERC1155MagicDropMetadataCloneable token;

    address owner = address(0x1234);
    address user = address(0xABCD);
    address royaltyReceiver = address(0x9999);

    uint256 internal constant TOKEN_ID = 1;
    uint256 internal constant TOKEN_ID_2 = 2;

    function setUp() public {
        token = TestableERC1155MagicDropMetadataCloneable(
            LibClone.deployERC1967(address(new TestableERC1155MagicDropMetadataCloneable()))
        );
        token.initialize("Test Collection", "TST", owner);
    }

    /*==============================================================
    =                         INITIALIZATION                       =
    ==============================================================*/

    function testInitialization() public view {
        assertEq(token.owner(), owner);
        assertEq(token.name(), "Test Collection");
        assertEq(token.symbol(), "TST");
        assertEq(token.baseURI(), "");
        assertEq(token.contractURI(), "");
        // maxSupply, walletLimit, and royalty not set for tokenId yet
        assertEq(token.maxSupply(TOKEN_ID), 0);
        assertEq(token.walletLimit(TOKEN_ID), 0);
        assertEq(token.totalSupply(TOKEN_ID), 0);
        assertEq(token.totalMinted(TOKEN_ID), 0);
        assertEq(token.royaltyAddress(), address(0));
        assertEq(token.royaltyBps(), 0);
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        token.initialize("Test Collection", "TST", owner);
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

        // setMaxSupply
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setMaxSupply(TOKEN_ID, 1000);

        // setWalletLimit
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setWalletLimit(TOKEN_ID, 20);

        // setRoyaltyInfo
        vm.prank(user);
        vm.expectRevert(Ownable.Unauthorized.selector);
        token.setRoyaltyInfo(royaltyReceiver, 500);
    }

    /*==============================================================
    =                          ADMIN OPERATIONS                    =
    ==============================================================*/

    function testSetBaseURI() public {
        vm.prank(owner);
        token.setBaseURI("https://example.com/metadata/");
        assertEq(token.baseURI(), "https://example.com/metadata/");
    }

    function testSetContractURI() public {
        vm.prank(owner);
        token.setContractURI("https://new-contract-uri.json");
        assertEq(token.contractURI(), "https://new-contract-uri.json");
    }

    function testSetMaxSupplyBasic() public {
        vm.startPrank(owner);
        token.setMaxSupply(TOKEN_ID, 1000);
        vm.stopPrank();
        assertEq(token.maxSupply(TOKEN_ID), 1000);
    }

    function testSetMaxSupplyDecreaseNotBelowMinted() public {
        vm.startPrank(owner);
        token.mintForTest(user, TOKEN_ID, 10);
        // Currently minted = 10
        vm.expectRevert(IMagicDropMetadata.MaxSupplyCannotBeLessThanCurrentSupply.selector);
        token.setMaxSupply(TOKEN_ID, 5);

        // Setting exactly to 10 should pass if we first set initial max supply
        token.setMaxSupply(TOKEN_ID, 1000); // set initial max supply
        token.setMaxSupply(TOKEN_ID, 10); // now decrease to minted
        assertEq(token.maxSupply(TOKEN_ID), 10);
        vm.stopPrank();
    }

    function testSetMaxSupplyCannotIncreaseBeyondOriginal() public {
        vm.startPrank(owner);
        token.setMaxSupply(TOKEN_ID, 1000);
        vm.expectRevert(IMagicDropMetadata.MaxSupplyCannotBeIncreased.selector);
        token.setMaxSupply(TOKEN_ID, 2000);
        vm.stopPrank();
    }

    function testSetMaxSupplyToCurrentSupply() public {
        vm.startPrank(owner);
        token.mintForTest(user, TOKEN_ID, 10);
        token.setMaxSupply(TOKEN_ID, 10);
        assertEq(token.maxSupply(TOKEN_ID), 10);
        vm.stopPrank();
    }

    function testMintIncreasesTotalSupply() public {
        vm.startPrank(owner);
        token.mintForTest(user, TOKEN_ID, 10);
        assertEq(token.totalSupply(TOKEN_ID), 10);
        vm.stopPrank();
    }

    function testMintIncreasesTotalMinted() public {
        vm.startPrank(owner);
        token.mintForTest(user, TOKEN_ID, 10);
        assertEq(token.totalMinted(TOKEN_ID), 10);
        vm.stopPrank();
    }

    function testSetWalletLimit() public {
        vm.startPrank(owner);
        token.setWalletLimit(TOKEN_ID, 20);
        assertEq(token.walletLimit(TOKEN_ID), 20);
        vm.stopPrank();
    }

    function testSetZeroWalletLimit() public {
        vm.startPrank(owner);
        token.setWalletLimit(TOKEN_ID, 0);
        assertEq(token.walletLimit(TOKEN_ID), 0);
        vm.stopPrank();
    }

    function testSetRoyaltyInfo() public {
        vm.startPrank(owner);
        token.setRoyaltyInfo(royaltyReceiver, 500);

        assertEq(token.royaltyAddress(), royaltyReceiver);
        assertEq(token.royaltyBps(), 500);

        // Check ERC2981 royaltyInfo
        (address receiver, uint256 amount) = IERC2981(address(token)).royaltyInfo(TOKEN_ID, 10_000);
        assertEq(receiver, royaltyReceiver);
        assertEq(amount, 500); // 5% of 10000 = 500
        vm.stopPrank();
    }

    function testSetRoyaltyInfoZeroAddress() public {
        vm.startPrank(owner);
        vm.expectRevert();
        token.setRoyaltyInfo(address(0), 1000);
        vm.stopPrank();
    }

    function testSetURI() public {
        vm.startPrank(owner);
        token.setBaseURI("https://example.com/metadata/");
        assertEq(token.uri(TOKEN_ID), "https://example.com/metadata/");
        vm.stopPrank();
    }

    function testEmitBatchMetadataUpdate() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IMagicDropMetadata.BatchMetadataUpdate(TOKEN_ID, 10);
        token.emitBatchMetadataUpdate(TOKEN_ID, 10);
        vm.stopPrank();
    }

    function testMaxSupplyCannotBeGreaterThan2ToThe64thPower() public {
        vm.startPrank(owner);
        vm.expectRevert(IMagicDropMetadata.MaxSupplyCannotBeGreaterThan2ToThe64thPower.selector);
        token.setMaxSupply(TOKEN_ID, 2 ** 64);
        vm.stopPrank();
    }

    /*==============================================================
    =                         METADATA TESTS                       =
    ==============================================================*/

    function testSupportsInterface() public view {
        // ERC2981 interfaceId = 0x2a55205a
        assertTrue(token.supportsInterface(0x2a55205a));
        // ERC4906 interfaceId = 0x49064906
        assertTrue(token.supportsInterface(0x49064906));
        // ERC1155 interfaceId = 0xd9b67a26
        assertTrue(token.supportsInterface(0xd9b67a26));
        // Some random interface
        assertFalse(token.supportsInterface(0x12345678));
    }
}
