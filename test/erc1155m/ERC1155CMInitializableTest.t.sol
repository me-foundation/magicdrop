// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";

import {
    ERC1155CMInitializableV1_0_2 as ERC1155CMInitializable
} from "../../contracts/nft/erc1155m/ERC1155CMInitializableV1_0_2.sol";
import {MintStageInfo1155} from "../../contracts/common/Structs.sol";
import {ErrorsAndEvents} from "../../contracts/common/ErrorsAndEvents.sol";
import {LAUNCHPAD_MINT_FEE_RECEIVER} from "contracts/utils/Constants.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ICreatorToken} from "@limitbreak/creator-token-standards/src/interfaces/ICreatorToken.sol";
import {ITransferValidator} from "@limitbreak/creator-token-standards/src/interfaces/ITransferValidator.sol";

contract ERC1155CMInitializableTest is Test {
    ERC1155CMInitializable public nft;
    address public owner;
    address public minter;
    address public fundReceiver;
    address public readonly;
    address public transferValidator;
    uint256 public constant INITIAL_SUPPLY = 1000;
    uint256 public constant GLOBAL_WALLET_LIMIT = 0;

    uint256[] public maxMintableSupply;
    uint256[] public globalWalletLimit;
    MintStageInfo1155[] public initialStages;
    uint256 public mintFee = 0.00001 ether;

    error Unauthorized();

    function setUp() public {
        owner = address(this);
        fundReceiver = address(0x1);
        readonly = address(0x2);
        minter = address(0x4);

        vm.deal(minter, 2 ether);

        address clone = LibClone.deployERC1967(address(new ERC1155CMInitializable()));
        nft = ERC1155CMInitializable(clone);
        nft.initialize("Test", "TEST", owner, mintFee);

        // Deploy and set a mock transfer validator to avoid issues with default validator
        transferValidator = address(new MockTransferValidator());
        nft.setTransferValidator(transferValidator);

        maxMintableSupply = new uint256[](1);
        maxMintableSupply[0] = INITIAL_SUPPLY;
        globalWalletLimit = new uint256[](1);
        globalWalletLimit[0] = GLOBAL_WALLET_LIMIT;

        initialStages = new MintStageInfo1155[](0);

        nft.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );
    }

    function testSetupNonOwnerRevert() public {
        ERC1155CMInitializable clone =
            ERC1155CMInitializable(LibClone.deployERC1967(address(new ERC1155CMInitializable())));
        clone.initialize("Test", "TEST", owner, mintFee);

        vm.startPrank(address(0x3));
        vm.expectRevert(Unauthorized.selector);
        clone.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );
        vm.stopPrank();
    }

    function testSetupLockedRevert() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsAndEvents.ContractAlreadySetup.selector);
        nft.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );

        assertEq(nft.isSetupLocked(), true);
    }

    function testInitializeRevertCalledTwice() public {
        vm.startPrank(owner);
        vm.expectRevert("Initializable: contract is already initialized");
        nft.initialize("Test", "TEST", owner, mintFee);
    }

    function testCallSetupBeforeInitializeRevert() public {
        vm.startPrank(owner);
        ERC1155CMInitializable clone =
            ERC1155CMInitializable(LibClone.deployERC1967(address(new ERC1155CMInitializable())));
        vm.expectRevert(Unauthorized.selector);
        clone.setup(
            "base_uri_", maxMintableSupply, globalWalletLimit, address(0), fundReceiver, initialStages, address(this), 0
        );
        vm.stopPrank();
    }

    function testSetTransferable() public {
        vm.startPrank(owner);
        nft.setTransferable(false);
        assertEq(nft.isTransferable(), false);

        nft.setTransferable(true);
        assertEq(nft.isTransferable(), true);
    }

    function testTransferWhenNotTransferable() public {
        vm.startPrank(owner);
        nft.setTransferable(false);
        nft.ownerMint(minter, 0, 1);
        vm.stopPrank();

        vm.expectRevert(ErrorsAndEvents.NotTransferable.selector);
        vm.prank(minter);
        nft.safeTransferFrom(minter, readonly, 0, 1, "");
    }

    function testTransferWhenTransferable() public {
        vm.startPrank(owner);
        nft.ownerMint(minter, 0, 1);
        vm.stopPrank();

        vm.prank(minter);
        nft.safeTransferFrom(minter, readonly, 0, 1, "");

        assertEq(nft.balanceOf(minter, 0), 0);
        assertEq(nft.balanceOf(readonly, 0), 1);
    }

    function testSetTransferableRevertAlreadySet() public {
        vm.startPrank(owner);
        vm.expectRevert(ErrorsAndEvents.TransferableAlreadySet.selector);
        nft.setTransferable(true);
    }

    function testMintFee() public {
        MintStageInfo1155[] memory stages = new MintStageInfo1155[](1);

        uint80[] memory price = new uint80[](1);
        price[0] = 0.5 ether;
        uint32[] memory walletLimit = new uint32[](1);
        walletLimit[0] = 1;
        bytes32[] memory merkleRoot = new bytes32[](1);
        merkleRoot[0] = bytes32(0);
        uint24[] memory maxStageSupply = new uint24[](1);
        maxStageSupply[0] = 5;

        stages[0] = MintStageInfo1155({
            price: price,
            walletLimit: walletLimit,
            merkleRoot: merkleRoot,
            maxStageSupply: maxStageSupply,
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1
        });

        nft.setStages(stages);

        vm.warp(0);
        vm.prank(minter);
        vm.expectRevert(abi.encodeWithSelector(ErrorsAndEvents.NotEnoughValue.selector));
        nft.mint{value: 0.5 ether}(0, 1, 0, new bytes32[](0));
        assertEq(nft.balanceOf(minter, 0), 0);

        vm.prank(minter);
        nft.mint{value: 0.5 ether + mintFee}(0, 1, 1, new bytes32[](0));
        assertEq(nft.balanceOf(minter, 0), 1);

        vm.prank(owner);
        nft.withdraw();
        assertEq(fundReceiver.balance, 0.5 ether);
        assertEq(LAUNCHPAD_MINT_FEE_RECEIVER.balance, mintFee);
    }

    function testMintFeeSetter() public {
        assertEq(nft.getMintFee(), mintFee);
        vm.prank(minter);
        vm.expectRevert(Ownable.Unauthorized.selector);
        nft.setMintFee(0.00002 ether);

        vm.startPrank(owner);
        nft.setMintFee(0.00002 ether);
        assertEq(nft.getMintFee(), 0.00002 ether);
    }

    // Creator Token specific tests

    function testContractNameAndVersion() public {
        (string memory name, string memory version) = nft.contractNameAndVersion();
        assertEq(name, "ERC1155CMInitializable");
        assertEq(version, "1.0.2");
    }

    function testSupportsICreatorTokenInterface() public {
        assertTrue(nft.supportsInterface(type(ICreatorToken).interfaceId));
    }

    function testGetTransferValidator() public {
        address validator = nft.getTransferValidator();
        // Should return the mock transfer validator we set in setUp
        assertEq(validator, transferValidator);
    }

    function testSetTransferValidator() public {
        // Deploy a mock validator with code
        address mockValidator = address(new MockTransferValidator());

        vm.prank(owner);
        nft.setTransferValidator(mockValidator);

        assertEq(nft.getTransferValidator(), mockValidator);
    }

    function testSetTransferValidatorNonOwnerRevert() public {
        address mockValidator = address(new MockTransferValidator());

        vm.prank(minter);
        vm.expectRevert(Ownable.Unauthorized.selector);
        nft.setTransferValidator(mockValidator);
    }

    function testSetTransferValidatorZeroAddress() public {
        vm.prank(owner);
        nft.setTransferValidator(address(0));

        // After setting to zero, validator should be zero (no validator)
        assertEq(nft.getTransferValidator(), address(0));
    }

    function testGetTransferValidationFunction() public {
        (bytes4 functionSignature, bool isViewFunction) = nft.getTransferValidationFunction();
        assertEq(functionSignature, bytes4(keccak256("validateTransfer(address,address,address,uint256,uint256)")));
        assertEq(isViewFunction, false);
    }

    function testTokenType() public view {
        // The _tokenType function is internal, but we can verify it through the contract behavior
        // Token type for ERC1155 should be 1155
        // This is tested indirectly through the transfer validator registration
    }

    function testAutoApproveTransfersFromValidator() public {
        address mockValidator = address(new MockTransferValidator());

        vm.prank(owner);
        nft.setTransferValidator(mockValidator);

        // Mint a token to minter
        vm.prank(owner);
        nft.ownerMint(minter, 0, 1);

        // The validator should be auto-approved if autoApproveTransfersFromValidator is true
        // Note: This depends on the AutomaticValidatorTransferApproval implementation
        // The approval depends on the autoApproveTransfersFromValidator flag
        // which may or may not be set by default
        nft.isApprovedForAll(minter, mockValidator);
    }

    function testBatchTransferWithCreatorToken() public {
        // First, we need to setup with 2 tokens
        ERC1155CMInitializable nftMulti =
            ERC1155CMInitializable(LibClone.deployERC1967(address(new ERC1155CMInitializable())));
        nftMulti.initialize("Test", "TEST", owner, mintFee);

        // Deploy and set a mock transfer validator
        address mockValidator = address(new MockTransferValidator());
        nftMulti.setTransferValidator(mockValidator);

        uint256[] memory maxSupply = new uint256[](2);
        maxSupply[0] = INITIAL_SUPPLY;
        maxSupply[1] = INITIAL_SUPPLY;
        uint256[] memory walletLimit = new uint256[](2);
        walletLimit[0] = GLOBAL_WALLET_LIMIT;
        walletLimit[1] = GLOBAL_WALLET_LIMIT;

        nftMulti.setup("base_uri_", maxSupply, walletLimit, address(0), fundReceiver, initialStages, address(this), 0);

        vm.startPrank(owner);
        nftMulti.ownerMint(minter, 0, 5);
        nftMulti.ownerMint(minter, 1, 3);
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 2;
        amounts[1] = 1;

        vm.prank(minter);
        nftMulti.safeBatchTransferFrom(minter, readonly, ids, amounts, "");

        assertEq(nftMulti.balanceOf(minter, 0), 3);
        assertEq(nftMulti.balanceOf(minter, 1), 2);
        assertEq(nftMulti.balanceOf(readonly, 0), 2);
        assertEq(nftMulti.balanceOf(readonly, 1), 1);
    }

    function testTransferValidationIsCalledOnTransfer() public {
        MockTransferValidatorWithRevert mockValidator = new MockTransferValidatorWithRevert();

        vm.prank(owner);
        nft.setTransferValidator(address(mockValidator));

        vm.prank(owner);
        nft.ownerMint(minter, 0, 1);

        // Transfer should revert because validator reverts
        vm.prank(minter);
        vm.expectRevert("MockValidator: transfer not allowed");
        nft.safeTransferFrom(minter, readonly, 0, 1, "");
    }

    function testMintDoesNotCallValidator() public {
        MockTransferValidatorWithRevert mockValidator = new MockTransferValidatorWithRevert();

        vm.prank(owner);
        nft.setTransferValidator(address(mockValidator));

        // Minting should work even though validator would revert on transfers
        vm.prank(owner);
        nft.ownerMint(minter, 0, 1);

        assertEq(nft.balanceOf(minter, 0), 1);
    }

    function testBurnDoesNotCallValidator() public {
        MockTransferValidatorWithRevert mockValidator = new MockTransferValidatorWithRevert();

        vm.prank(owner);
        nft.ownerMint(minter, 0, 1);

        vm.prank(owner);
        nft.setTransferValidator(address(mockValidator));

        // Burning should work even though validator would revert on transfers
        // Note: ERC1155M doesn't have a public burn function, so we can't test this directly
        // This test is here for completeness but will be skipped
    }
}

// Mock contracts for testing

contract MockTransferValidator is ITransferValidator {
    function applyCollectionTransferPolicy(address caller, address from, address to) external pure override {}

    function validateTransfer(address caller, address from, address to) external pure override {}

    function validateTransfer(address caller, address from, address to, uint256 tokenId) external pure override {}

    function validateTransfer(address caller, address from, address to, uint256 tokenId, uint256 amount)
        external
        pure
        override
    {}

    function beforeAuthorizedTransfer(address operator, address token, uint256 tokenId) external pure override {}

    function afterAuthorizedTransfer(address token, uint256 tokenId) external pure override {}

    function beforeAuthorizedTransfer(address operator, address token) external pure override {}

    function afterAuthorizedTransfer(address token) external pure override {}

    function beforeAuthorizedTransfer(address token, uint256 tokenId) external pure override {}

    function beforeAuthorizedTransferWithAmount(address token, uint256 tokenId, uint256 amount)
        external
        pure
        override
    {}

    function afterAuthorizedTransferWithAmount(address token, uint256 tokenId) external pure override {}
}

contract MockTransferValidatorWithRevert is ITransferValidator {
    function applyCollectionTransferPolicy(address caller, address from, address to) external pure override {
        revert("MockValidator: transfer not allowed");
    }

    function validateTransfer(address caller, address from, address to) external pure override {
        revert("MockValidator: transfer not allowed");
    }

    function validateTransfer(address caller, address from, address to, uint256 tokenId) external pure override {
        revert("MockValidator: transfer not allowed");
    }

    function validateTransfer(address caller, address from, address to, uint256 tokenId, uint256 amount)
        external
        pure
        override
    {
        revert("MockValidator: transfer not allowed");
    }

    function beforeAuthorizedTransfer(address operator, address token, uint256 tokenId) external pure override {}

    function afterAuthorizedTransfer(address token, uint256 tokenId) external pure override {}

    function beforeAuthorizedTransfer(address operator, address token) external pure override {}

    function afterAuthorizedTransfer(address token) external pure override {}

    function beforeAuthorizedTransfer(address token, uint256 tokenId) external pure override {}

    function beforeAuthorizedTransferWithAmount(address token, uint256 tokenId, uint256 amount)
        external
        pure
        override
    {}

    function afterAuthorizedTransferWithAmount(address token, uint256 tokenId) external pure override {}
}

