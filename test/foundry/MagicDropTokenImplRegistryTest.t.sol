// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/MagicDropTokenImplRegistry.sol";
import {TokenStandard} from  "../../contracts/common/Structs.sol";

contract MockImplementation {}

contract MagicDropTokenImplRegistryTest is Test {
    MagicDropTokenImplRegistry registry;
    address owner = address(0x1);
    address user = address(0x2);
    MockImplementation mockImpl;

    function setUp() public {
        vm.startPrank(owner);
        registry = new MagicDropTokenImplRegistry();
        registry.initialize();
        vm.stopPrank();
        mockImpl = new MockImplementation();
    }

    function testRegisterImplementation() public {
        vm.prank(owner);
        uint256 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockImpl));
        assertEq(implId, 1);
        assertEq(registry.getImplementation(TokenStandard.ERC721, implId), address(mockImpl));
    }

    function testRegisterMultipleImplementations() public {
        vm.startPrank(owner);
        uint256 implId1 = registry.registerImplementation(TokenStandard.ERC721, address(mockImpl));
        uint256 implId2 = registry.registerImplementation(TokenStandard.ERC721, address(0x3));
        vm.stopPrank();

        assertEq(implId1, 1);
        assertEq(implId2, 2);
        assertEq(registry.getImplementation(TokenStandard.ERC721, implId1), address(mockImpl));
        assertEq(registry.getImplementation(TokenStandard.ERC721, implId2), address(0x3));
    }

    function testUnregisterImplementation() public {
        vm.startPrank(owner);
        uint256 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockImpl));
        registry.unregisterImplementation(TokenStandard.ERC721, implId);
        vm.stopPrank();

        assertEq(registry.getImplementation(TokenStandard.ERC721, implId), address(0));
    }

    function testFailUnregisterNonExistentImplementation() public {
        vm.prank(owner);
        registry.unregisterImplementation(TokenStandard.ERC721, 0);
    }

    function testFailRegisterImplementationAsNonOwner() public {
        vm.prank(user);
        registry.registerImplementation(TokenStandard.ERC721, address(mockImpl));
    }

    function testFailUnregisterImplementationAsNonOwner() public {
        vm.prank(owner);
        uint256 implId = registry.registerImplementation(TokenStandard.ERC721, address(mockImpl));
        
        vm.prank(user);
        registry.unregisterImplementation(TokenStandard.ERC721, implId);
    }
}
