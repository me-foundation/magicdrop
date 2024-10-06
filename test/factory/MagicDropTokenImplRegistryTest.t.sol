// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MagicDropTokenImplRegistry} from "../../contracts/registry/MagicDropTokenImplRegistry.sol";
import {TokenStandard} from "../../contracts/common/Structs.sol";
import {MockERC721} from "solady/test/utils/mocks/MockERC721.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

interface IMagicDropTokenImplRegistryRaw {
    function registerImplementation(uint8 tokenStandard, address implementation) external returns (uint32);
}

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
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721));
        assertEq(implId, 1);
        (address impl, bool deprecated) = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
        assertFalse(deprecated);
    }

    function testRegisterMultipleImplementations() public {
        vm.startPrank(owner);
        uint32 implId1 = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721));
        uint32 implId2 = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721));
        vm.stopPrank();

        assertEq(implId1, 1);
        assertEq(implId2, 2); // ensure the implId is incremented

        (address impl1,) = registry.getImplementation(TokenStandard.ERC721, implId1);
        (address impl2,) = registry.getImplementation(TokenStandard.ERC721, implId2);

        assertEq(impl1, address(mockERC721));
        assertEq(impl2, address(mockERC721));
    }

    function testFailRegisterImplementationAsNonOwner() public {
        vm.prank(user);
        registry.registerImplementation(TokenStandard.ERC721, address(mockERC721));
    }

    function testGetImplementation() public {
        vm.prank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721));
        (address impl, bool deprecated) = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
        assertFalse(deprecated);
    }

    function testGetImplementationDeprecated() public {
        vm.startPrank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721));
        registry.deprecateImplementation(TokenStandard.ERC721, implId);
        (address impl, bool deprecated) = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
        assertTrue(deprecated);
        vm.stopPrank();
    }

    function testRegisterUnsupportedStandard() public {
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                MagicDropTokenImplRegistry.ImplementationDoesNotSupportStandard.selector, TokenStandard.ERC1155
            )
        );
        // register as erc1155 with erc721 impl
        registry.registerImplementation(TokenStandard.ERC1155, address(mockERC721));
    }
}
