// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MagicDropTokenImplRegistry} from "../../contracts/registry/MagicDropTokenImplRegistry.sol";
import {TokenStandard} from "../../contracts/common/Structs.sol";
import {MockERC721} from "solady/test/utils/mocks/MockERC721.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {IERC165} from "openzeppelin-contracts/contracts/interfaces/IERC165.sol";

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

    /*==============================================================
    =                      REGISTRATION                            =
    ==============================================================*/

    function testRegisterImplementation() public {
        vm.prank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        assertEq(implId, 1);
        address impl = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
    }

    function testRegisterMultipleImplementations(uint256 numImplementations) public {
        vm.startPrank(owner);

        // bound the number of implementations
        numImplementations = bound(numImplementations, 1, 25);

        for (uint256 i = 0; i < numImplementations; i++) {
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        }
        vm.stopPrank();

        for (uint256 i = 0; i < numImplementations; i++) {
            uint32 implId = uint32(i + 1);
            address impl = registry.getImplementation(TokenStandard.ERC721, implId);
            assertEq(impl, address(mockERC721));
        }
    }

    function testRegisterUnsupportedStandard() public {
        vm.prank(owner);
        vm.expectRevert(MagicDropTokenImplRegistry.ImplementationDoesNotSupportStandard.selector);
        // register as erc1155 with erc721 impl
        registry.registerImplementation(TokenStandard.ERC1155, address(mockERC721), false);
    }

    function testFailRegisterImplementationAsNonOwner() public {
        vm.prank(user);
        registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
    }

    /*==============================================================
    =                      UNREGISTRATION                          =
    ==============================================================*/

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

    function testUnregisterImplementationInvalidImplementation() public {
        vm.prank(owner);
        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.unregisterImplementation(TokenStandard.ERC721, 1);
    }

    /*==============================================================
    =                      GET IMPLEMENTATION                      =
    ==============================================================*/

    function testGetImplementation() public {
        vm.prank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false);
        address impl = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
    }

    function testGetImplementationInvalidImplementation() public {
        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.getImplementation(TokenStandard.ERC721, 1);
    }

    function testGetDefaultImplementation() public {
        vm.prank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), true);
        address impl = registry.getDefaultImplementation(TokenStandard.ERC721);
        assertEq(impl, address(mockERC721));
    }

    function testGetDefaultImplementationNotRegistered() public {
        vm.expectRevert(MagicDropTokenImplRegistry.DefaultImplementationNotRegistered.selector);
        registry.getDefaultImplementation(TokenStandard.ERC721);
    }

    function testGetDefaultImplementationID() public {
        vm.prank(owner);
        uint32 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), true);
        uint32 defaultImplId = registry.getDefaultImplementationID(TokenStandard.ERC721);
        assertEq(defaultImplId, implId);
    }

    function testGetDefaultImplementationIDNotRegistered() public {
        vm.expectRevert(MagicDropTokenImplRegistry.DefaultImplementationNotRegistered.selector);
        registry.getDefaultImplementationID(TokenStandard.ERC721);
    }
}
