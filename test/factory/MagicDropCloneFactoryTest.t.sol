// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC721} from "solady/test/utils/mocks/MockERC721.sol";
import {MockERC1155} from "solady/test/utils/mocks/MockERC1155.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

import {MagicDropCloneFactory} from "../../contracts/factory/MagicDropCloneFactory.sol";
import {MagicDropTokenImplRegistry} from "../../contracts/registry/MagicDropTokenImplRegistry.sol";
import {TokenStandard} from "../../contracts/common/Structs.sol";

contract MockERC721Initializable is MockERC721 {
    function initialize(string memory, string memory, address) public {}
}

contract MockERC1155Initializable is MockERC1155 {
    function initialize(string memory, string memory, address) public {}
}

contract InvalidImplementation is MockERC721 {
    function initialize(string memory) public {} // Missing name and symbol parameters
}

contract MagicDropCloneFactoryTest is Test {
    MagicDropCloneFactory internal factory;
    MagicDropTokenImplRegistry internal registry;

    MockERC721Initializable internal erc721Impl;
    MockERC1155Initializable internal erc1155Impl;
    address internal owner = address(0x1);
    address internal user = address(0x2);

    uint32 internal erc721ImplId;
    uint32 internal erc1155ImplId;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy and initialize registry
        MagicDropTokenImplRegistry registryImpl = new MagicDropTokenImplRegistry();
        registry = MagicDropTokenImplRegistry(LibClone.deployERC1967(address(registryImpl)));
        registry.initialize(owner);

        // Deploy factory
        MagicDropCloneFactory factoryImpl = new MagicDropCloneFactory();
        factory = MagicDropCloneFactory(LibClone.deployERC1967(address(factoryImpl)));
        factory.initialize(owner, address(registry));

        // Deploy implementations
        erc721Impl = new MockERC721Initializable();
        erc1155Impl = new MockERC1155Initializable();

        // Register implementations
        erc721ImplId = registry.registerImplementation(TokenStandard.ERC721, address(erc721Impl));
        erc1155ImplId = registry.registerImplementation(TokenStandard.ERC1155, address(erc1155Impl));

        vm.stopPrank();
    }

    function testCreateERC721Contract() public {
        vm.startPrank(user);

        address newContract =
            factory.createContract("TestNFT", "TNFT", TokenStandard.ERC721, payable(user), erc721ImplId);

        MockERC721Initializable nft = MockERC721Initializable(newContract);

        // Test minting
        nft.mint(user, 1);
        assertEq(nft.ownerOf(1), user);

        vm.stopPrank();
    }

    function testCreateERC1155Contract() public {
        vm.startPrank(user);

        address newContract =
            factory.createContract("TestMultiToken", "TMT", TokenStandard.ERC1155, payable(user), erc1155ImplId);

        MockERC1155Initializable nft = MockERC1155Initializable(newContract);

        // Test minting
        nft.mint(user, 1, 100, "");
        assertEq(nft.balanceOf(user, 1), 100);

        vm.stopPrank();
    }

    function testCreateContractWithDifferentSalts() public {
        vm.startPrank(user);

        address contract1 = factory.createContractDeterministic(
            "TestNFT1", "TNFT1", TokenStandard.ERC721, payable(user), erc721ImplId, bytes32(uint256(0))
        );
        address contract2 = factory.createContractDeterministic(
            "TestNFT2", "TNFT2", TokenStandard.ERC721, payable(user), erc721ImplId, bytes32(uint256(1))
        );

        assertTrue(contract1 != contract2);

        vm.stopPrank();
    }

    function testFailCreateContractWithInvalidImplementation() public {
        uint32 invalidImplId = 999;

        vm.prank(user);
        factory.createContract("TestNFT", "TNFT", TokenStandard.ERC721, payable(user), invalidImplId);
    }

    function testCreateDeterministicContractWithSameSalt() public {
        vm.startPrank(user);

        factory.createContractDeterministic(
            "TestNFT1", "TNFT1", TokenStandard.ERC721, payable(user), erc721ImplId, bytes32(0)
        );

        vm.expectRevert(abi.encodeWithSelector(MagicDropCloneFactory.SaltAlreadyUsed.selector, bytes32(0)));

        factory.createContractDeterministic(
            "TestNFT2", "TNFT2", TokenStandard.ERC721, payable(user), erc721ImplId, bytes32(0)
        );
    }

    function testContractAlreadyDeployed() public {
        bytes32 salt = bytes32(uint256(1));
        uint32 implId = 1;
        TokenStandard standard = TokenStandard.ERC721;
        address initialOwner = address(0x1);
        string memory name = "TestToken";
        string memory symbol = "TT";

        // Predict the address where the contract will be deployed
        address predictedAddress = factory.predictDeploymentAddress(standard, implId, salt);

        // Deploy a dummy contract to the predicted address
        vm.etch(predictedAddress, address(erc721Impl).code);

        // Try to create a contract with the same parameters
        vm.expectRevert(
            abi.encodeWithSelector(MagicDropCloneFactory.ContractAlreadyDeployed.selector, predictedAddress)
        );
        factory.createContractDeterministic(name, symbol, standard, payable(initialOwner), implId, salt);
    }

    function testIsSaltUsed() public {
        bytes32 salt = bytes32(uint256(1));
        assertTrue(!factory.isSaltUsed(salt));
        factory.createContractDeterministic("TestNFT", "TNFT", TokenStandard.ERC721, payable(user), erc721ImplId, salt);
        assertTrue(factory.isSaltUsed(salt));
    }

    function testImplementationDeprecated() public {
        TokenStandard standard = TokenStandard.ERC721;

        vm.startPrank(owner);
        uint32 implId = registry.registerImplementation(standard, address(erc721Impl));
        registry.deprecateImplementation(standard, implId);
        vm.stopPrank();

        vm.expectRevert(MagicDropCloneFactory.ImplementationDeprecated.selector);
        factory.createContractDeterministic("TestNFT", "TNFT", standard, payable(user), implId, bytes32(0));
    }

    function testImplementationNotRegistered() public {
        TokenStandard standard = TokenStandard.ERC721;
        uint32 implId = 999;

        vm.expectRevert(MagicDropCloneFactory.ImplementationNotRegistered.selector);
        factory.createContractDeterministic("TestNFT", "TNFT", standard, payable(user), implId, bytes32(0));
    }

    function testInitializationFailed() public {
        TokenStandard standard = TokenStandard.ERC721;

        vm.startPrank(owner);
        InvalidImplementation impl = new InvalidImplementation();
        uint32 implId = registry.registerImplementation(standard, address(impl));
        vm.stopPrank();

        vm.expectRevert(MagicDropCloneFactory.InitializationFailed.selector);
        factory.createContractDeterministic("TestNFT", "TNFT", standard, payable(user), implId, bytes32(0));
    }
}