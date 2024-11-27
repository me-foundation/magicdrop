// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
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
    address internal owner = payable(address(0x1));
    address internal user = payable(address(0x2));

    uint32 internal erc721ImplId;
    uint32 internal erc1155ImplId;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy and initialize registry
        MagicDropTokenImplRegistry registryImpl = new MagicDropTokenImplRegistry(owner);
        registry = MagicDropTokenImplRegistry(address(registryImpl));

        // Deploy factory
        MagicDropCloneFactory factoryImpl = new MagicDropCloneFactory(owner, address(registry));
        factory = MagicDropCloneFactory(payable(address(factoryImpl)));

        // Deploy implementations
        erc721Impl = new MockERC721Initializable();
        erc1155Impl = new MockERC1155Initializable();

        // Register implementations
        erc721ImplId = registry.registerImplementation(TokenStandard.ERC721, address(erc721Impl), true, 0.01 ether);
        erc1155ImplId = registry.registerImplementation(TokenStandard.ERC1155, address(erc1155Impl), true, 0.01 ether);

        // Fund user
        vm.deal(user, 100 ether);

        vm.stopPrank();
    }

    function testCreateERC721Contract() public {
        vm.startPrank(user);

        address newContract = factory.createContract{value: 0.01 ether}(
            "TestNFT", "TNFT", TokenStandard.ERC721, payable(user), erc721ImplId
        );

        MockERC721Initializable nft = MockERC721Initializable(newContract);

        // Test minting
        nft.mint(user, 1);
        assertEq(nft.ownerOf(1), user);

        vm.stopPrank();
    }

    function testCreateERC721ContractWithDefaultImplementation() public {
        vm.startPrank(user);

        address newContract =
            factory.createContract{value: 0.01 ether}("TestNFT", "TNFT", TokenStandard.ERC721, payable(user), 0);

        MockERC721Initializable nft = MockERC721Initializable(newContract);
        // Test minting
        nft.mint(user, 1);
        assertEq(nft.ownerOf(1), user);

        vm.stopPrank();
    }

    function testCreateERC1155Contract() public {
        vm.startPrank(user);

        address newContract = factory.createContract{value: 0.01 ether}(
            "TestMultiToken", "TMT", TokenStandard.ERC1155, payable(user), erc1155ImplId
        );

        MockERC1155Initializable nft = MockERC1155Initializable(newContract);

        // Test minting
        nft.mint(user, 1, 100, "");
        assertEq(nft.balanceOf(user, 1), 100);

        vm.stopPrank();
    }

    function testCreateERC1155ContractWithDefaultImplementation() public {
        vm.startPrank(user);

        address newContract =
            factory.createContract{value: 0.01 ether}("TestMultiToken", "TMT", TokenStandard.ERC1155, payable(user), 0);

        MockERC1155Initializable nft = MockERC1155Initializable(newContract);

        // Test minting
        nft.mint(user, 1, 100, "");
        assertEq(nft.balanceOf(user, 1), 100);

        vm.stopPrank();
    }

    function testCreateContractWithDifferentSalts(uint256 numSalts) public {
        vm.startPrank(user);

        numSalts = bound(numSalts, 10, 100);
        bytes32[] memory salts = new bytes32[](numSalts);

        for (uint256 i = 0; i < numSalts; i++) {
            salts[i] = keccak256(abi.encodePacked(i, block.timestamp, msg.sender));
            address predictedAddress = factory.predictDeploymentAddress(TokenStandard.ERC721, erc721ImplId, salts[i]);
            address deployedAddress = factory.createContractDeterministic{value: 0.01 ether}(
                "TestNFT", "TNFT", TokenStandard.ERC721, payable(user), erc721ImplId, salts[i]
            );
            assertEq(predictedAddress, deployedAddress);
        }

        vm.stopPrank();
    }

    function testFailCreateContractWithInvalidImplementation() public {
        uint32 invalidImplId = 999;

        vm.prank(user);
        factory.createContract("TestNFT", "TNFT", TokenStandard.ERC721, payable(user), invalidImplId);
    }

    function testFailCreateDeterministicContractWithSameSalt() public {
        vm.startPrank(user);

        factory.createContractDeterministic{value: 0.01 ether}(
            "TestNFT1", "TNFT1", TokenStandard.ERC721, payable(user), erc721ImplId, bytes32(0)
        );

        factory.createContractDeterministic{value: 0.01 ether}(
            "TestNFT2", "TNFT2", TokenStandard.ERC721, payable(user), erc721ImplId, bytes32(0)
        );
    }

    function testFailContractAlreadyDeployed() public {
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
        factory.createContractDeterministic{value: 0.01 ether}(
            name, symbol, standard, payable(initialOwner), implId, salt
        );
    }

    function testInitializationFailed() public {
        TokenStandard standard = TokenStandard.ERC721;

        vm.startPrank(owner);
        InvalidImplementation impl = new InvalidImplementation();
        uint32 implId = registry.registerImplementation(standard, address(impl), false, 0.01 ether);
        vm.stopPrank();

        vm.expectRevert(MagicDropCloneFactory.InitializationFailed.selector);
        factory.createContractDeterministic{value: 0.01 ether}(
            "TestNFT", "TNFT", standard, payable(user), implId, bytes32(0)
        );
    }

    function testInsufficientDeploymentFee() public {
        vm.startPrank(user);
        vm.expectRevert(MagicDropCloneFactory.InsufficientDeploymentFee.selector);
        factory.createContractDeterministic{value: 0.005 ether}(
            "TestNFT", "TNFT", TokenStandard.ERC721, payable(user), erc721ImplId, bytes32(0)
        );
    }

    function testGetRegistry() public view {
        assertEq(factory.getRegistry(), address(registry));
    }

    function testWithdraw() public {
        vm.startPrank(user);
        factory.createContract{value: 0.01 ether}("TestMultiToken", "TMT", TokenStandard.ERC1155, payable(user), 0);
        vm.stopPrank();

        vm.startPrank(owner);
        uint256 userBalanceBefore = user.balance;
        assertEq(address(factory).balance, 0.01 ether);
        factory.withdraw(user);
        assertEq(address(factory).balance, 0);
        assertEq(user.balance, userBalanceBefore + 0.01 ether);
        vm.stopPrank();
    }

    function testFailWithdrawToNonOwner() public {
        vm.startPrank(user);
        factory.withdraw(user);
    }
}
