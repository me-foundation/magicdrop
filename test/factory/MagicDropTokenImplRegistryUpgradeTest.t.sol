// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MagicDropTokenImplRegistry} from "../../contracts/registry/MagicDropTokenImplRegistry.sol";
import {UUPSUpgradeable} from "solady/src/utils/UUPSUpgradeable.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {TokenStandard} from "../../contracts/common/Structs.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC721MagicDropCloneable} from "../../contracts/nft/erc721m/clones/ERC721MagicDropCloneable.sol";

contract MagicDropTokenImplRegistryV2 is MagicDropTokenImplRegistry {
    // New storage variable
    uint256 private _maxFee;

    // Reduce gap by 1
    uint256[47] private __gap;

    // New function to test upgrade
    function setMaxFee(uint256 newFee) external onlyOwner {
        _maxFee = newFee;
    }

    function getMaxFee() external view returns (uint256) {
        return _maxFee;
    }

    // Required override for UUPS
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}

contract MagicDropTokenImplRegistryV3 is MagicDropTokenImplRegistryV2 {
    // New state variable for V3
    string public version;

    function initializeV3(string memory _version) external onlyOwner {
        version = _version;
    }
}

contract MagicDropTokenImplRegistryUpgradeTest is Test {
    MagicDropTokenImplRegistry public registry;
    MagicDropTokenImplRegistryV2 public registryV2;
    address public registryProxy;
    address public owner;
    address public erc721;

    function setUp() public {
        owner = address(this);

        // Deploy implementation
        registry = new MagicDropTokenImplRegistry();

        // Deploy proxy
        registryProxy = LibClone.deployERC1967(address(registry));

        // Initialize proxy
        MagicDropTokenImplRegistry(payable(registryProxy)).initialize(owner);

        // Deploy V2 implementation (but don't upgrade yet)
        registryV2 = new MagicDropTokenImplRegistryV2();

        // Deploy mock ERC721 that supports IERC165
        erc721 = address(new ERC721MagicDropCloneable());
    }

    function test_UpgradeToV2() public {
        MagicDropTokenImplRegistry registryPrxy = MagicDropTokenImplRegistry(payable(registryProxy));

        // Register implementation before upgrade
        uint32 implId = registryPrxy.registerImplementation(TokenStandard.ERC721, erc721, true, 0.01 ether, 0.01 ether);
        assertEq(registryPrxy.getDefaultImplementationID(TokenStandard.ERC721), implId);

        // Upgrade to V2
        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(registryV2), "");

        MagicDropTokenImplRegistryV2 registryV2Proxy = MagicDropTokenImplRegistryV2(payable(registryProxy));

        // Test new V2 functionality
        registryV2Proxy.setMaxFee(1 ether);
        assertEq(registryV2Proxy.getMaxFee(), 1 ether);

        // Verify old state is preserved
        assertEq(registryV2Proxy.getDefaultImplementationID(TokenStandard.ERC721), implId);
        assertEq(registryV2Proxy.getDefaultImplementation(TokenStandard.ERC721), erc721);
    }

    function test_CannotUpgradeUnauthorized() public {
        vm.prank(address(0xdead));
        vm.expectRevert(Ownable.Unauthorized.selector);
        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(registryV2), "");
    }

    function test_CannotUpgradeToInvalidImplementation() public {
        MockInvalidImplementation invalidImpl = new MockInvalidImplementation();

        vm.expectRevert(UUPSUpgradeable.UpgradeFailed.selector);
        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(invalidImpl), "");
    }

    function test_CannotInitializeImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        registry.initialize(owner);
    }

    function test_UpgradeWithInitializer() public {
        bytes memory initData = abi.encodeCall(MagicDropTokenImplRegistryV2.setMaxFee, (1 ether));

        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(registryV2), initData);

        MagicDropTokenImplRegistryV2 registryV2Proxy = MagicDropTokenImplRegistryV2(payable(registryProxy));
        assertEq(registryV2Proxy.getMaxFee(), 1 ether);
    }

    function test_CannotUpgradeToZeroAddress() public {
        vm.expectRevert(MagicDropTokenImplRegistry.NewImplementationCannotBeZero.selector);
        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(0), "");
    }

    function test_NonOwnerCannotCallNewFunction() public {
        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(registryV2), "");
        MagicDropTokenImplRegistryV2 registryV2Proxy = MagicDropTokenImplRegistryV2(payable(registryProxy));

        vm.prank(address(0xdeadbeef));
        vm.expectRevert(Ownable.Unauthorized.selector);
        registryV2Proxy.setMaxFee(1 ether);
    }

    function test_MultipleUpgrades() public {
        // --- Initial state (V1) ---
        uint32 implIdV1 = MagicDropTokenImplRegistry(payable(registryProxy)).registerImplementation(
            TokenStandard.ERC721, erc721, true, 0.01 ether, 0.01 ether
        );
        assertEq(
            MagicDropTokenImplRegistry(payable(registryProxy)).getDefaultImplementationID(TokenStandard.ERC721),
            implIdV1
        );

        // --- Upgrade to V2 ---
        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(registryV2), "");
        MagicDropTokenImplRegistryV2 registryV2Proxy = MagicDropTokenImplRegistryV2(payable(registryProxy));

        // Test V2 functionality while preserving V1 state
        registryV2Proxy.setMaxFee(1 ether);
        assertEq(registryV2Proxy.getMaxFee(), 1 ether);
        assertEq(registryV2Proxy.getDefaultImplementationID(TokenStandard.ERC721), implIdV1);

        // --- Upgrade to V3 ---
        MagicDropTokenImplRegistryV3 registryV3 = new MagicDropTokenImplRegistryV3();
        bytes memory v3InitData = abi.encodeWithSignature("initializeV3(string)", "v3");

        UUPSUpgradeable(registryProxy).upgradeToAndCall(address(registryV3), v3InitData);
        MagicDropTokenImplRegistryV3 registryV3Proxy = MagicDropTokenImplRegistryV3(payable(registryProxy));

        // Verify all state is preserved
        assertEq(registryV3Proxy.getDefaultImplementationID(TokenStandard.ERC721), implIdV1);
        assertEq(registryV3Proxy.getMaxFee(), 1 ether);
        assertEq(registryV3Proxy.version(), "v3");
    }
}

// Helper contracts
contract MockInvalidImplementation {
    function initialize(address owner) external {}
}
