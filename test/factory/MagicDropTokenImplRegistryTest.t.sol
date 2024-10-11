// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MagicDropTokenImplRegistry} from "../../contracts/registry/MagicDropTokenImplRegistry.sol";
import {TokenStandard} from "../../contracts/common/Structs.sol";
import {MockERC721} from "solady/test/utils/mocks/MockERC721.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

contract MagicDropTokenImplRegistryTest is Test {
    MagicDropTokenImplRegistry internal registry;
    address internal owner = address(0x1);
    address internal user = address(0x2);
    MockERC721 internal mockERC721;

    function setUp() public {
        vm.startPrank(owner);
        MagicDropTokenImplRegistry registryImpl = new MagicDropTokenImplRegistry();
        registry = MagicDropTokenImplRegistry(LibClone.deployERC1967(address(registryImpl)));
        registry.initialize(owner);
        vm.stopPrank();
        mockERC721 = new MockERC721();
    }

    function testRegisterImplementation() public {
        vm.prank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        assertEq(implId, 1);
        address impl = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
    }

    function testRegisterMultipleImplementations() public {
        vm.startPrank(owner);
        uint32 implId1 = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        uint32 implId2 = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        vm.stopPrank();

        assertEq(implId1, 1);
        assertEq(implId2, 2); // ensure the implId is incremented

        address impl1 = registry.getImplementation(TokenStandard.ERC721, implId1);
        address impl2 = registry.getImplementation(TokenStandard.ERC721, implId2);

        assertEq(impl1, address(mockERC721));
        assertEq(impl2, address(mockERC721));
    }

    function testFailRegisterImplementationAsNonOwner() public {
        vm.prank(user);
        registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
    }

    function testGetImplementation() public {
        vm.prank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        address impl = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
    }

    function testRegisterUnsupportedStandard() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                MagicDropTokenImplRegistry.ImplementationDoesNotSupportStandard.selector, TokenStandard.ERC1155
            )
        );
        // register as erc1155 with erc721 impl
        registry.registerImplementation(TokenStandard.ERC1155, address(mockERC721), false);
    }

    function testUnregisterImplementation() public {
        vm.startPrank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        registry.unregisterImplementation(TokenStandard.ERC721, implId);
        vm.stopPrank();

        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.getImplementation(TokenStandard.ERC721, implId);
    }

    function testFailUnregisterImplementationAsNonOwner() public {
        vm.prank(user);
        registry.unregisterImplementation(TokenStandard.ERC721, 1);
    }

    function testUnregisterImplementationNotRegistered() public {
        vm.prank(owner);
        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.unregisterImplementation(TokenStandard.ERC721, 1);
    }
}
