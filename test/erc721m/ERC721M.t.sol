// test/foundry/erc721m/ERC721M.t.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {ERC721M} from "contracts/nft/erc721m/ERC721M.sol";
import {MintStageInfo} from "contracts/common/Structs.sol";

contract ERC721MTest is Test {
    ERC721M public erc721m;

    address public owner;
    address public fundReceiver;
    uint256 public chainId;

    // These live in a library. They should live on the contract at the lowest level possible.
    error InsufficientStageTimeGap();
    error InvalidStartAndEndTimestamp();
    error InvalidStage();
    error NotMintable();
    error NotEnoughValue();
    error Reentrancy();
    error CannotIncreaseMaxMintableSupply();
    error NoSupplyLeft();
    error WalletStageLimitExceeded();
    error StageSupplyExceeded();
    error GlobalWalletLimitOverflow();
    error URIQueryForNonexistentToken();

    function setUp() public {
        owner = address(this);
        fundReceiver = makeAddr("fundReceiver");

        chainId = block.chainid;

        erc721m = new ERC721M("Test", "TEST", "suffix", 1000, 1000, address(this), 300, address(0), fundReceiver, 0);
    }

    function testInitialState() public {
        assertEq(erc721m.name(), "Test");
        assertEq(erc721m.symbol(), "TEST");
        assertEq(erc721m.getMaxMintableSupply(), 1000);
        assertEq(erc721m.getGlobalWalletLimit(), 1000);
        assertEq(erc721m.owner(), owner);
    }

    function testContractCanBePausedUnpaused() public {
        // starts unpaused
        assertTrue(erc721m.getMintable());

        erc721m.setMintable(false);
        assertFalse(erc721m.getMintable());

        erc721m.setMintable(true);
        assertTrue(erc721m.getMintable());
    }

    function testWithdrawByOwner() public {
        // Fund contract
        deal(address(erc721m), 100);

        uint256 fundReceiverBalanceBefore = address(fundReceiver).balance;

        // Owner withdraws
        erc721m.withdraw();

        // Funds should go to fundReceiver
        assertEq(address(erc721m).balance, 0);
        assertEq(address(fundReceiver).balance, fundReceiverBalanceBefore + 100);

        // Non-owner cannot withdraw
        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        vm.expectRevert();
        erc721m.withdraw();
    }

    function testDeployment() public {
        assertEq(erc721m.getCosigner(), address(this));

        erc721m.getCosignDigest(owner, 1, false, 0, 0);
    }

    function testDeployment0x0Cosigner() public {
        address zeroAddress = address(0);
        address cosigner = address(1);

        ERC721M erc721mTest =
            new ERC721M("Test", "TEST", "test/", 1000, 10, zeroAddress, 300, zeroAddress, fundReceiver, 0);

        vm.expectRevert();
        erc721mTest.getCosignDigest(owner, 1, false, 0, 0);

        erc721mTest.setCosigner(cosigner);
    }

    function testTokenURISuffix() public {
        erc721m.setCosigner(address(0));
        erc721m.setTokenURISuffix(".json");
        erc721m.setBaseURI("ipfs://bafybeidntqfipbuvdhdjosntmpxvxyse2dkyfpa635u4g6txruvt5qf7y4/");
        // Create stage data
        MintStageInfo[] memory stages = new MintStageInfo[](1);

        // Configure the stage fields individually
        stages[0].price = uint80(0.1 ether);
        stages[0].walletLimit = 0;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 0;
        stages[0].startTimeUnixSeconds = block.timestamp;
        stages[0].endTimeUnixSeconds = block.timestamp + 1;

        // Set the stages
        erc721m.setStages(stages);

        // Create empty proof array for the mint
        bytes32[] memory proof = new bytes32[](0);

        // Mint token with required payment
        uint256 mintFee = 0; // Adjust if your contract has a mint fee
        erc721m.mint{value: 0.11 ether + mintFee}(1, 0, proof, 0, hex"00");
    }

    function testSetStages() public {
        // Create stage data with proper Solidity syntax
        MintStageInfo[] memory stages = new MintStageInfo[](1);

        // Set values separately to avoid type conversion issues
        uint256 price = 0.1 ether;
        uint256 startTime = block.timestamp;
        uint256 endTime = block.timestamp + 1 days;

        // Configure the stage fields individually
        stages[0].price = uint80(price);
        stages[0].walletLimit = 5;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 100;
        stages[0].startTimeUnixSeconds = startTime;
        stages[0].endTimeUnixSeconds = endTime;

        // Set the stages
        erc721m.setStages(stages);

        // Verify stage was set correctly
        (MintStageInfo memory stageInfo, uint32 walletMinted, uint256 stageMinted) = erc721m.getStageInfo(0);

        assertEq(stageInfo.price, uint80(price));
        assertEq(stageInfo.walletLimit, 5);
        assertEq(stageInfo.merkleRoot, bytes32(0));
        assertEq(stageInfo.maxStageSupply, 100);
        assertEq(stageInfo.startTimeUnixSeconds, startTime);
        assertEq(stageInfo.endTimeUnixSeconds, endTime);
        assertEq(walletMinted, 0);
        assertEq(stageMinted, 0);

        // Test non-owner cannot set stages
        address nonOwner = makeAddr("nonOwner");
        vm.prank(nonOwner);
        vm.expectRevert();
        erc721m.setStages(stages);
    }

    function testStagesInsufficientGap() public {
        MintStageInfo[] memory stages = new MintStageInfo[](2);

        stages[0].price = uint80(0.5 ether);
        stages[0].walletLimit = 3;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1;

        stages[1].price = uint80(0.6 ether);
        stages[1].walletLimit = 4;
        stages[1].merkleRoot = bytes32(0);
        stages[1].maxStageSupply = 10;
        stages[1].startTimeUnixSeconds = 60;
        stages[1].endTimeUnixSeconds = 62;

        vm.expectRevert(InsufficientStageTimeGap.selector);

        erc721m.setStages(stages);
    }

    function testStartTime() public {
        MintStageInfo[] memory stages = new MintStageInfo[](2);

        stages[0].price = uint80(0.5 ether);
        stages[0].walletLimit = 3;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 0;

        stages[1].price = uint80(0.6 ether);
        stages[1].walletLimit = 4;
        stages[1].merkleRoot = bytes32(0);
        stages[1].maxStageSupply = 10;
        stages[1].startTimeUnixSeconds = 61;
        stages[1].endTimeUnixSeconds = 61;

        vm.expectRevert(InvalidStartAndEndTimestamp.selector);
        erc721m.setStages(stages);

        stages[0].startTimeUnixSeconds = 1;
        stages[0].endTimeUnixSeconds = 0;

        stages[1].startTimeUnixSeconds = 62;
        stages[1].endTimeUnixSeconds = 61;

        vm.expectRevert(InvalidStartAndEndTimestamp.selector);
        erc721m.setStages(stages);
    }

    function testResetStages() public {
        MintStageInfo[] memory stages = new MintStageInfo[](2);

        stages[0].price = uint80(0.5 ether);
        stages[0].walletLimit = 3;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1;

        // Some configurable expiry default hidden somewhere in code effects the gap between end/start times. See: getTimestampExpirySeconds
        stages[1].price = uint80(0.6 ether);
        stages[1].walletLimit = 4;
        stages[1].merkleRoot = bytes32(0);
        stages[1].maxStageSupply = 10;
        stages[1].startTimeUnixSeconds = 301;
        stages[1].endTimeUnixSeconds = 302;

        erc721m.setStages(stages);

        assertEq(erc721m.getNumberStages(), 2);

        MintStageInfo[] memory newStages = new MintStageInfo[](1);

        newStages[0].price = uint80(0.7 ether);
        newStages[0].walletLimit = 5;
        newStages[0].merkleRoot = bytes32(0);
        newStages[0].maxStageSupply = 0;
        newStages[0].startTimeUnixSeconds = 0;
        newStages[0].endTimeUnixSeconds = 1;

        erc721m.setStages(newStages);

        assertEq(erc721m.getNumberStages(), 1);
    }

    function testGetStageInfo() public {
        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0.5 ether);
        stages[0].walletLimit = 3;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1;

        erc721m.setStages(stages);

        (MintStageInfo memory stageInfo, uint32 walletMintedCount, uint256 stageMinted) = erc721m.getStageInfo(0);

        assertEq(stageInfo.price, uint80(0.5 ether));
        assertEq(stageInfo.walletLimit, 3);
        assertEq(stageInfo.merkleRoot, bytes32(0));
        assertEq(stageInfo.maxStageSupply, 5);
        assertEq(stageInfo.startTimeUnixSeconds, 0);
        assertEq(stageInfo.endTimeUnixSeconds, 1);
        assertEq(walletMintedCount, 0);
        assertEq(stageMinted, 0);
    }

    function testRevertGetStageInfoNonExistentStage() public {
        vm.expectRevert(InvalidStage.selector);
        erc721m.getStageInfo(1);
    }

    function testGetActiveStageFromTimestamp() public {
        MintStageInfo[] memory stages = new MintStageInfo[](2);

        stages[0].price = uint80(0.5 ether);
        stages[0].walletLimit = 3;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1;

        stages[1].price = uint80(0.6 ether);
        stages[1].walletLimit = 4;
        stages[1].merkleRoot = bytes32(0);
        stages[1].maxStageSupply = 10;
        stages[1].startTimeUnixSeconds = 301;
        stages[1].endTimeUnixSeconds = 302;

        erc721m.setStages(stages);

        assertEq(erc721m.getNumberStages(), 2);
        assertEq(erc721m.getActiveStageFromTimestamp(0), 0);
        assertEq(erc721m.getActiveStageFromTimestamp(301), 1);

        vm.expectRevert(InvalidStage.selector);
        erc721m.getActiveStageFromTimestamp(70);
    }

    function testRevertIfNotMintable() public {
        erc721m.setMintable(false);

        // Create empty proof array for the mint
        bytes32[] memory proof = new bytes32[](0);

        // Mint token with required payment
        uint256 mintFee = 0;

        vm.expectRevert(NotMintable.selector);
        erc721m.mint{value: 0.11 ether + mintFee}(1, 0, proof, 0, hex"00");
    }

    function testRevertIfWithoutStages() public {
        // Create empty proof array for the mint
        bytes32[] memory proof = new bytes32[](0);

        // Mint token with required payment
        uint256 mintFee = 0;

        erc721m.setCosigner(address(0));

        vm.expectRevert(InvalidStage.selector);
        erc721m.mint{value: 0.11 ether + mintFee}(1, 0, proof, 0, hex"00");
    }

    function testRevertIfNotEnoughValue() public {
        erc721m.setCosigner(address(0));

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0.4 ether);
        stages[0].walletLimit = 10;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721m.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);
        uint256 mintFee = 0;

        vm.expectRevert(NotEnoughValue.selector);
        erc721m.mint{value: 0.399 ether + mintFee}(1, 0, proof, 0, hex"00");
    }

    function testRevertOnReentrancy() public {
        TestReentrantExploit exploit = new TestReentrantExploit(address(erc721m));

        vm.deal(address(exploit), 100 ether);

        erc721m.setCosigner(address(0));
        erc721m.setMintable(true);
        erc721m.setCosigner(address(0));

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0.4 ether);
        stages[0].walletLimit = 10;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721m.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);

        vm.startPrank(address(exploit));
        vm.expectRevert(Reentrancy.selector);
        erc721m.mint{value: 0.4 ether}(1, 0, proof, 0, hex"00");
        vm.stopPrank();
    }

    function testSetMaxMintableSupply() public {
        erc721m.setMaxMintableSupply(100);
        assertEq(erc721m.getMaxMintableSupply(), 100);

        erc721m.setMaxMintableSupply(100);
        assertEq(erc721m.getMaxMintableSupply(), 100);

        erc721m.setMaxMintableSupply(99);
        assertEq(erc721m.getMaxMintableSupply(), 99);

        vm.expectRevert(CannotIncreaseMaxMintableSupply.selector);
        erc721m.setMaxMintableSupply(101);
    }

    function testMintOverMaxMintableSupply() public {
        erc721m.setMaxMintableSupply(99);

        erc721m.setCosigner(address(0));
        erc721m.setMintable(true);

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0.4 ether);
        stages[0].walletLimit = 10;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 5;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721m.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);

        vm.expectRevert(NoSupplyLeft.selector);
        erc721m.mint{value: 40 ether}(100, 0, proof, 0, hex"00");
    }

    function testMintWithWalletLimit() public {
        erc721m.setMaxMintableSupply(999);

        erc721m.setCosigner(address(0));
        erc721m.setMintable(true);

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0.4 ether);
        stages[0].walletLimit = 10;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 0;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721m.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);

        erc721m.mint{value: 4 ether}(10, 0, proof, 0, hex"00");

        vm.expectRevert(WalletStageLimitExceeded.selector);
        erc721m.mint{value: 0.4 ether}(1, 0, proof, 0, hex"00");
    }

    function testMintWithLimitedStageSupply() public {
        erc721m.setMaxMintableSupply(999);

        erc721m.setCosigner(address(0));
        erc721m.setMintable(true);

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0.4 ether);
        stages[0].walletLimit = 0;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 10;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721m.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);

        vm.expectRevert(StageSupplyExceeded.selector);
        erc721m.mint{value: 4.4 ether}(11, 0, proof, 0, hex"00");
    }

    function testMintForFree() public {
        erc721m.setMaxMintableSupply(999);

        erc721m.setCosigner(address(0));
        erc721m.setMintable(true);

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0 ether);
        stages[0].walletLimit = 0;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 10;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721m.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);

        erc721m.mint{value: 0 ether}(1, 0, proof, 0, hex"00");
    }

    function testMintForFreeWithAFee() public {
        ERC721M erc721mFee =
            new ERC721M("Test", "TEST", "test/", 1000, 1000, address(this), 300, address(0), fundReceiver, 0.1 ether);

        erc721mFee.setCosigner(address(0));
        erc721mFee.setMintable(true);

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0 ether);
        stages[0].walletLimit = 0;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 10;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721mFee.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);

        uint256 initialBalance = address(erc721mFee).balance;
        erc721mFee.mint{value: 0.1 ether}(1, 0, proof, 0, hex"00");
        assertEq(address(erc721mFee).balance, initialBalance + 0.1 ether);
    }

    function testTokenURI() public {
        vm.expectRevert(URIQueryForNonexistentToken.selector);
        erc721m.tokenURI(0);

        erc721m.setMaxMintableSupply(999);

        erc721m.setCosigner(address(0));
        erc721m.setMintable(true);

        MintStageInfo[] memory stages = new MintStageInfo[](1);

        stages[0].price = uint80(0 ether);
        stages[0].walletLimit = 0;
        stages[0].merkleRoot = bytes32(0);
        stages[0].maxStageSupply = 10;
        stages[0].startTimeUnixSeconds = 0;
        stages[0].endTimeUnixSeconds = 1_000_000_000 ether;

        erc721m.setStages(stages);

        bytes32[] memory proof = new bytes32[](0);

        erc721m.mint{value: 0 ether}(1, 0, proof, 0, hex"00");

        erc721m.setBaseURI("base_uri_");
        assertEq(erc721m.tokenURI(0), "base_uri_0suffix");
        erc721m.setBaseURI("");
        assertEq(erc721m.tokenURI(0), "");
    }

    //describe('Token URI', function () {

    // Helper function to generate signatures
    function _getCosignSignature(address cosigner, address recipient, uint256 timestamp, uint256 qty, bool feeWaived)
        internal
        returns (bytes memory)
    {
        bytes32 digest = erc721m.getCosignDigest(recipient, uint32(qty), feeWaived, 0, timestamp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(uint256(keccak256(abi.encodePacked(cosigner))), digest);
        return abi.encodePacked(r, s, v);
    }

    function testGlobalWalletConstructorLimit() public {
        vm.expectRevert(GlobalWalletLimitOverflow.selector);
        new ERC721M("Test", "TEST", "", 100, 1001, address(0), 60, address(0), fundReceiver, 0.1 ether);
    }

    function testSetGlobalWalletLimit() public {
        erc721m.setGlobalWalletLimit(2);
        assertEq(erc721m.getGlobalWalletLimit(), 2);

        vm.expectRevert(GlobalWalletLimitOverflow.selector);
        erc721m.setGlobalWalletLimit(1001);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        return this.onERC721Received.selector;
    }
}

contract TestReentrantExploit {
    ERC721M public erc721m;

    constructor(address _erc721m) {
        erc721m = ERC721M(_erc721m);
    }

    function exploit(bytes32[] memory proof, uint256 timestamp, bytes memory signature) public payable {
        erc721m.mint{value: 0.4 ether}(1, 0, proof, timestamp, signature);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        bytes32[] memory proof = new bytes32[](0);
        exploit(proof, block.timestamp, hex"00");
        return this.onERC721Received.selector;
    }
}
