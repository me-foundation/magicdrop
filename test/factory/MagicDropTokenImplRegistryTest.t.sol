// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

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
    address internal manager = address(0x3);
    MockERC721 internal mockERC721;

    function setUp() public {
        vm.startPrank(owner);
        address registryImpl = LibClone.clone(address(new MagicDropTokenImplRegistry()));
        registry = MagicDropTokenImplRegistry(payable(registryImpl));
        registry.initialize(owner);
        registry.grantRoles(manager, registry.MANAGER_ROLE());
        vm.stopPrank();
        mockERC721 = new MockERC721();
    }

    /*==============================================================
    =                      REGISTRATION                            =
    ==============================================================*/

    function testRegisterImplementation() public {
        vm.prank(owner);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        assertEq(implId, 1);
        address impl = registry.getImplementation(TokenStandard.ERC721, implId);
        uint256 deploymentFee = registry.getDeploymentFee(TokenStandard.ERC721, implId);
        uint256 mintFee = registry.getMintFee(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
        assertEq(deploymentFee, 0.01 ether);
        assertEq(mintFee, 0.00001 ether);
    }

    function testRegisterMultipleImplementations(uint256 numImplementations, uint256 deploymentFee, uint256 mintFee)
        public
    {
        vm.startPrank(owner);

        // bound the number of implementations
        numImplementations = bound(numImplementations, 1, 25);
        deploymentFee = bound(deploymentFee, 0.01 ether, 1 ether);
        mintFee = bound(mintFee, 0.00001 ether, 0.01 ether);

        for (uint256 i = 0; i < numImplementations; i++) {
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, deploymentFee, mintFee);
        }
        vm.stopPrank();

        for (uint256 i = 0; i < numImplementations; i++) {
            uint32 implId = uint32(i + 1);
            address impl = registry.getImplementation(TokenStandard.ERC721, implId);
            uint256 deploymentFee_ = registry.getDeploymentFee(TokenStandard.ERC721, implId);
            uint256 mintFee_ = registry.getMintFee(TokenStandard.ERC721, implId);
            assertEq(impl, address(mockERC721));
            assertEq(deploymentFee_, deploymentFee);
            assertEq(mintFee_, mintFee);
        }
    }

    function testRegisterUnsupportedStandard() public {
        vm.prank(owner);
        vm.expectRevert(MagicDropTokenImplRegistry.ImplementationDoesNotSupportStandard.selector);
        // register as erc1155 with erc721 impl
        registry.registerImplementation(TokenStandard.ERC1155, address(mockERC721), false, 0.01 ether, 0.00001 ether);
    }

    function testRegisterImplementationAsNonOwner() public {
        vm.prank(user);
        vm.expectRevert();
        registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
    }

    function testRegisterImplementationAsManager() public {
        vm.prank(manager);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        assertEq(implId, 1);
        address impl = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
    }

    /*==============================================================
    =                      UNREGISTRATION                          =
    ==============================================================*/

    function testUnregisterImplementation() public {
        vm.startPrank(owner);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        registry.unregisterImplementation(TokenStandard.ERC721, implId);
        vm.stopPrank();

        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.getImplementation(TokenStandard.ERC721, implId);
    }

    function testUnregisterImplementationAsNonOwner() public {
        vm.prank(user);
        vm.expectRevert();
        registry.unregisterImplementation(TokenStandard.ERC721, 1);
    }

    function testUnregisterImplementationInvalidImplementation() public {
        vm.prank(owner);
        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.unregisterImplementation(TokenStandard.ERC721, 1);
    }

    function testUnregisterImplementationAsManager() public {
        vm.startPrank(manager);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        registry.unregisterImplementation(TokenStandard.ERC721, implId);
        vm.stopPrank();

        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.getImplementation(TokenStandard.ERC721, implId);
    }

    /*==============================================================
    =                      GET IMPLEMENTATION                      =
    ==============================================================*/

    function testGetImplementation() public {
        vm.prank(owner);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        address impl = registry.getImplementation(TokenStandard.ERC721, implId);
        assertEq(impl, address(mockERC721));
    }

    function testGetImplementationInvalidImplementation() public {
        vm.expectRevert(MagicDropTokenImplRegistry.InvalidImplementation.selector);
        registry.getImplementation(TokenStandard.ERC721, 1);
    }

    function testGetDefaultImplementation() public {
        vm.prank(owner);
        registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), true, 0.01 ether, 0.00001 ether);
        address impl = registry.getDefaultImplementation(TokenStandard.ERC721);
        assertEq(impl, address(mockERC721));
    }

    function testGetDefaultImplementationNotRegistered() public {
        vm.expectRevert(MagicDropTokenImplRegistry.DefaultImplementationNotRegistered.selector);
        registry.getDefaultImplementation(TokenStandard.ERC721);
    }

    function testGetDefaultImplementationID() public {
        vm.prank(owner);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), true, 0.01 ether, 0.00001 ether);
        uint32 defaultImplId = registry.getDefaultImplementationID(TokenStandard.ERC721);
        assertEq(defaultImplId, implId);
    }

    function testGetDefaultImplementationIDNotRegistered() public {
        vm.expectRevert(MagicDropTokenImplRegistry.DefaultImplementationNotRegistered.selector);
        registry.getDefaultImplementationID(TokenStandard.ERC721);
    }

    /*==============================================================
    =                      DEPLOYMENT FEE                         =
    ==============================================================*/

    function testGetDeploymentFee() public {
        vm.prank(owner);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        uint256 deploymentFee = registry.getDeploymentFee(TokenStandard.ERC721, implId);
        assertEq(deploymentFee, 0.01 ether);
    }

    function testUpdateDeploymentFee() public {
        vm.prank(owner);
        registry.setDeploymentFee(TokenStandard.ERC721, 1, 0.02 ether);
        uint256 deploymentFee = registry.getDeploymentFee(TokenStandard.ERC721, 1);
        assertEq(deploymentFee, 0.02 ether);
    }

    function testUpdateDeploymentFeeAsManager() public {
        vm.startPrank(manager);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        registry.setDeploymentFee(TokenStandard.ERC721, implId, 0.02 ether);
        vm.stopPrank();

        uint256 deploymentFee = registry.getDeploymentFee(TokenStandard.ERC721, implId);
        assertEq(deploymentFee, 0.02 ether);
    }

    /*==============================================================
    =                           MINT FEE                           =
    ==============================================================*/

    function testGetMintFee() public {
        vm.prank(owner);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        uint256 mintFee = registry.getMintFee(TokenStandard.ERC721, implId);
        assertEq(mintFee, 0.00001 ether);
    }

    function testUpdateMintFee() public {
        vm.prank(owner);
        registry.setMintFee(TokenStandard.ERC721, 1, 0.00002 ether);
        uint256 mintFee = registry.getMintFee(TokenStandard.ERC721, 1);
        assertEq(mintFee, 0.00002 ether);
    }

    function testUpdateMintFeeAsManager() public {
        vm.startPrank(manager);
        uint32 implId =
            registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        registry.setMintFee(TokenStandard.ERC721, implId, 0.00002 ether);
        vm.stopPrank();

        uint256 mintFee = registry.getMintFee(TokenStandard.ERC721, implId);
        assertEq(mintFee, 0.00002 ether);
    }

    function testRevokeManagerRole() public {
        // Verify manager has role initially
        assertTrue(registry.hasAnyRole(manager, registry.MANAGER_ROLE()));

        // Revoke role as owner
        vm.startPrank(owner);
        registry.revokeRoles(manager, registry.MANAGER_ROLE());
        vm.stopPrank();

        // Verify manager no longer has role
        assertFalse(registry.hasAnyRole(manager, registry.MANAGER_ROLE()));

        // Verify manager can no longer perform privileged actions
        vm.startPrank(manager);
        vm.expectRevert();
        registry.registerImplementation(TokenStandard.ERC721, address(mockERC721), false, 0.01 ether, 0.00001 ether);
        vm.stopPrank();
    }
}
