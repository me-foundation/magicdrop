pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../contracts/factory/MagicDropCloneFactory.sol";
import "../../contracts/MagicDropTokenImplRegistry.sol";
import "../../contracts/nft/MagicDropERC721Initializable.sol";
import "../../contracts/nft/MagicDropERC1155Initializable.sol";
import {TokenStandard} from "../../contracts/common/Structs.sol";

contract MagicDropCloneFactoryTest is Test {
    MagicDropCloneFactory factory;
    MagicDropTokenImplRegistry registry;
    MagicDropERC721Initializable erc721Implementation;
    MagicDropERC1155Initializable erc1155Implementation;
    address owner = address(0x1);
    address user = address(0x2);

    uint256 erc721ImplId;
    uint256 erc1155ImplId;

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy and initialize registry
        registry = new MagicDropTokenImplRegistry();
        registry.initialize();

        // Deploy factory
        factory = new MagicDropCloneFactory(registry);
        factory.initialize();

        // Deploy implementations
        erc721Implementation = new MagicDropERC721Initializable();
        erc1155Implementation = new MagicDropERC1155Initializable();

        // Register implementations
        erc721ImplId = registry.registerImplementation(TokenStandard.ERC721, address(erc721Implementation));
        erc1155ImplId = registry.registerImplementation(TokenStandard.ERC1155, address(erc1155Implementation));

        vm.stopPrank();
    }

    function testCreateERC721Contract() public {
        vm.startPrank(user);
        
        address newContract = factory.createContract(
            "TestNFT",
            "TNFT",
            TokenStandard.ERC721,
            payable(user),
            erc721ImplId,
            bytes32(0)
        );

        MagicDropERC721Initializable nft = MagicDropERC721Initializable(newContract);
        assertEq(nft.name(), "TestNFT");
        assertEq(nft.symbol(), "TNFT");
        assertEq(nft.owner(), user);

        // Test minting
        nft.mint(user, 1);
        assertEq(nft.ownerOf(1), user);

        vm.stopPrank();
    }

    function testCreateERC1155Contract() public {
        vm.startPrank(user);
        
        address newContract = factory.createContract(
            "TestMultiToken",
            "TMT",
            TokenStandard.ERC1155,
            payable(user),
            erc1155ImplId,
            bytes32(0)
        );

        MagicDropERC1155Initializable multiToken = MagicDropERC1155Initializable(newContract);
        assertEq(multiToken.name(), "TestMultiToken");
        assertEq(multiToken.symbol(), "TMT");
        assertEq(multiToken.owner(), user);

        // Test minting
        multiToken.mint(user, 1, 100, "");
        assertEq(multiToken.balanceOf(user, 1), 100);

        vm.stopPrank();
    }

    function testCreateContractWithDifferentSalts() public {
        vm.startPrank(user);
        
        address contract1 = factory.createContract(
            "TestNFT1",
            "TNFT1",
            TokenStandard.ERC721,
            payable(user),
            erc721ImplId,
            bytes32(uint256(1))
        );

        address contract2 = factory.createContract(
            "TestNFT2",
            "TNFT2",
            TokenStandard.ERC721,
            payable(user),
            erc721ImplId,
            bytes32(uint256(2))
        );

        assertTrue(contract1 != contract2);

        vm.stopPrank();
    }

    function testFailCreateContractWithInvalidImplementation() public {
        uint256 invalidImplId = 999;

        vm.prank(user);
        factory.createContract(
            "TestNFT",
            "TNFT",
            TokenStandard.ERC721,
            payable(user),
            invalidImplId,
            bytes32(0)
        );
    }
}
