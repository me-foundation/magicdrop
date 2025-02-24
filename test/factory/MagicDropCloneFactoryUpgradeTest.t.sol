// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MagicDropCloneFactory} from "../../contracts/factory/MagicDropCloneFactory.sol";
import {MagicDropTokenImplRegistry} from "../../contracts/registry/MagicDropTokenImplRegistry.sol";
import {UUPSUpgradeable} from "solady/src/utils/UUPSUpgradeable.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC721MagicDropCloneable} from "../../contracts/nft/erc721m/clones/ERC721MagicDropCloneable.sol";
import {TokenStandard} from "../../contracts/common/Structs.sol";

contract MagicDropCloneFactoryV2 is MagicDropCloneFactory {
    // New storage variable (example)
    uint256 private _maxDeploymentFee;

    // New function to test upgrade
    function setMaxDeploymentFee(uint256 newFee) external onlyOwner {
        _maxDeploymentFee = newFee;
    }

    function getMaxDeploymentFee() external view returns (uint256) {
        return _maxDeploymentFee;
    }

    // Required override for UUPS
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}

// New upgradeable implementation V3 that extends V2 and introduces a new variable.
contract MagicDropCloneFactoryV3 is MagicDropCloneFactoryV2 {
    // New state variable for V3.
    string public version;

    // New function to initialize the version variable.
    function initializeV3(string memory _version) external onlyOwner {
        version = _version;
    }
}

contract MagicDropCloneFactoryUpgradeTest is Test {
    MagicDropCloneFactory public factory;
    MagicDropCloneFactoryV2 public factoryV2;
    address public registryProxy;
    address public factoryProxy;
    address public owner;
    address public registry;
    address public erc721;

    function setUp() public {
        owner = address(this);

        factory = new MagicDropCloneFactory();
        registry = address(new MagicDropTokenImplRegistry());

        // Deploy proxies
        registryProxy = LibClone.deployERC1967(address(registry));
        factoryProxy = LibClone.deployERC1967(address(factory));
        erc721 = address(new ERC721MagicDropCloneable());

        // Initialize the proxies
        MagicDropTokenImplRegistry(payable(registryProxy)).initialize(owner);
        MagicDropCloneFactory(payable(factoryProxy)).initialize(owner, registryProxy);

        // register erc721
        MagicDropTokenImplRegistry(payable(registryProxy)).registerImplementation(
            TokenStandard.ERC721, erc721, true, 0.01 ether, 0.01 ether
        );

        // Deploy V2 implementation (but don't upgrade yet)
        factoryV2 = new MagicDropCloneFactoryV2();
    }

    function test_UpgradeToV2() public {
        MagicDropCloneFactory factoryPrxy = MagicDropCloneFactory(payable(factoryProxy));

        // Verify initial state and deploy a collection before upgrade
        assertEq(factoryPrxy.getRegistry(), registryProxy);
        address collection = factoryPrxy.createContract("Test", "TEST", TokenStandard.ERC721, payable(owner), 0);
        assertTrue(collection != address(0));

        // Upgrade to V2
        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(factoryV2), "");

        MagicDropCloneFactoryV2 factoryV2Proxy = MagicDropCloneFactoryV2(payable(factoryProxy));

        // Test new V2 functionality
        factoryV2Proxy.setMaxDeploymentFee(1 ether);
        assertEq(factoryV2Proxy.getMaxDeploymentFee(), 1 ether);

        // Verify old state is preserved and can still deploy collections
        assertEq(factoryV2Proxy.getRegistry(), registryProxy);
        address collectionAfterUpgrade =
            factoryV2Proxy.createContract("Test", "TEST", TokenStandard.ERC721, payable(owner), 0);
        assertTrue(collectionAfterUpgrade != address(0));
    }

    function test_CannotUpgradeUnauthorized() public {
        vm.prank(address(0xdead));
        vm.expectRevert(Ownable.Unauthorized.selector);
        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(factoryV2), "");
    }

    function test_CannotUpgradeToInvalidImplementation() public {
        // Deploy an implementation without UUPS interface
        MockInvalidImplementation invalidImpl = new MockInvalidImplementation();

        vm.expectRevert(UUPSUpgradeable.UpgradeFailed.selector);
        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(invalidImpl), "");
    }

    function test_CannotInitializeImplementation() public {
        // Ensure implementation contract cannot be initialized directly
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        factory.initialize(owner, registry);
    }

    function test_UpgradeWithInitializer() public {
        bytes memory initData = abi.encodeCall(MagicDropCloneFactoryV2.setMaxDeploymentFee, (1 ether));

        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(factoryV2), initData);

        MagicDropCloneFactoryV2 factoryV2Proxy = MagicDropCloneFactoryV2(payable(factoryProxy));
        assertEq(factoryV2Proxy.getMaxDeploymentFee(), 1 ether);
    }

    function test_CannotUpgradeToZeroAddress() public {
        // We expect a revert when trying to upgrade to a zero address.
        vm.expectRevert();
        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(0), "");
    }

    function test_NonOwnerCannotCallNewFunction() public {
        // Upgrade the contract first.
        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(factoryV2), "");
        MagicDropCloneFactoryV2 factoryV2Proxy = MagicDropCloneFactoryV2(payable(factoryProxy));

        // Simulate a call from a non-owner address.
        vm.prank(address(0xdeadbeef));
        vm.expectRevert(Ownable.Unauthorized.selector);
        factoryV2Proxy.setMaxDeploymentFee(1 ether);
    }

    /// Test Multiple Upgrades: V1 -> V2 -> V3.
    function test_MultipleUpgrades() public {
        // --- Upgrade from V1 to V2 ---
        // Deploy a collection before any upgrades
        address collectionV1 = MagicDropCloneFactory(payable(factoryProxy)).createContract(
            "Test", "TEST", TokenStandard.ERC721, payable(owner), 0
        );
        assertTrue(collectionV1 != address(0));

        // Upgrade to V2 implementation
        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(factoryV2), "");
        MagicDropCloneFactoryV2 factoryV2Proxy = MagicDropCloneFactoryV2(payable(factoryProxy));

        // Verify V2 can deploy collections
        address collectionV2 = factoryV2Proxy.createContract("Test", "TEST", TokenStandard.ERC721, payable(owner), 0);
        assertTrue(collectionV2 != address(0));

        // Confirm that the state initialized in V1 is preserved
        assertEq(factoryV2Proxy.getRegistry(), registryProxy);
        factoryV2Proxy.setMaxDeploymentFee(1 ether);
        assertEq(factoryV2Proxy.getMaxDeploymentFee(), 1 ether);

        // --- Upgrade from V2 to V3 ---
        MagicDropCloneFactoryV3 factoryV3 = new MagicDropCloneFactoryV3();
        bytes memory v3InitData = abi.encodeWithSignature("initializeV3(string)", "v3");

        // Upgrade to V3
        UUPSUpgradeable(factoryProxy).upgradeToAndCall(address(factoryV3), v3InitData);
        MagicDropCloneFactoryV3 factoryV3Proxy = MagicDropCloneFactoryV3(payable(factoryProxy));

        // Verify V3 can still deploy collections
        address collectionV3 = factoryV3Proxy.createContract("Test", "TEST", TokenStandard.ERC721, payable(owner), 0);
        assertTrue(collectionV3 != address(0));

        // Verify all state is preserved
        assertEq(factoryV3Proxy.getRegistry(), registryProxy);
        assertEq(factoryV3Proxy.getMaxDeploymentFee(), 1 ether);
        assertEq(factoryV3Proxy.version(), "v3");
    }
}

// Helper contract for testing invalid implementations
contract MockInvalidImplementation {
    function initialize(address owner, address registry) external {}
}
