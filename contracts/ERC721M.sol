//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "hardhat/console.sol";
import "./IERC721M.sol";

contract ERC721M is IERC721M, ERC721AQueryable, Ownable {
    bool private _mintable;
    string private _currentBaseURI;
    uint256 private _activeStage;
    uint256 private _maxMintableSupply;
    uint256 private _globalWalletLimit;

    MintStageInfo[] private _mintStages;

    // Need this because struct cannot have nested mapping
    mapping(uint256 => mapping(address => uint32)) private _stageMintedCounts;
    mapping(uint256 => uint256) private _stageMintedSupply;

    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit
    ) ERC721A(collectionName, collectionSymbol) {
        if (globalWalletLimit > maxMintableSupply)
            revert GlobalWalletLimitOverflow();

        _mintable = false;
        _maxMintableSupply = maxMintableSupply;
        _globalWalletLimit = globalWalletLimit;
    }

    modifier canMint() {
        if (!_mintable) revert NotMintable();
        _;
    }

    modifier hasSupply(uint256 qty) {
        if (totalSupply() + qty > _maxMintableSupply) revert NoSupplyLeft();
        _;
    }

    function setStages(
        uint256[] memory prices,
        uint32[] memory walletLimits,
        bytes32[] memory merkleRoots,
        uint256[] memory maxStageSupplies
    ) external onlyOwner {
        // check all arrays are the same length
        if (prices.length != walletLimits.length)
            revert InvalidStageArgsLength();
        if (prices.length != merkleRoots.length)
            revert InvalidStageArgsLength();
        if (maxStageSupplies.length != merkleRoots.length)
            revert InvalidStageArgsLength();

        uint256 originalSize = _mintStages.length;
        for (uint256 i = 0; i < originalSize; i++) {
            _mintStages.pop();
        }

        for (uint256 i = 0; i < prices.length; i++) {
            _mintStages.push(
                MintStageInfo({
                    price: prices[i],
                    walletLimit: walletLimits[i],
                    merkleRoot: merkleRoots[i],
                    maxStageSupply: maxStageSupplies[i]
                })
            );
            emit UpdateStage(
                i,
                prices[i],
                walletLimits[i],
                merkleRoots[i],
                maxStageSupplies[i]
            );
        }
    }

    function getMintable() external view returns (bool) {
        return _mintable;
    }

    function setMintable(bool mintable) external onlyOwner {
        _mintable = mintable;
        emit SetMintable(mintable);
    }

    function getNumberStages() external view returns (uint256) {
        return _mintStages.length;
    }

    function getMaxMintableSupply() external view returns (uint256) {
        return _maxMintableSupply;
    }

    function setMaxMintableSupply(uint256 maxMintableSupply)
        external
        onlyOwner
    {
        _maxMintableSupply = maxMintableSupply;
        emit SetMaxMintableSupply(maxMintableSupply);
    }

    function getGlobalWalletLimit() external view returns (uint256) {
        return _globalWalletLimit;
    }

    function setGlobalWalletLimit(uint256 globalWalletLimit)
        external
        onlyOwner
    {
        if (globalWalletLimit > _maxMintableSupply)
            revert GlobalWalletLimitOverflow();
        _globalWalletLimit = globalWalletLimit;
        emit SetGlobalWalletLimit(globalWalletLimit);
    }

    function getActiveStage() external view returns (uint256) {
        return _activeStage;
    }

    function setActiveStage(uint256 activeStage) external onlyOwner {
        if (activeStage >= _mintStages.length) revert InvalidStage();
        _activeStage = activeStage;
        emit SetActiveStage(activeStage);
    }

    function totalMintedByAddress(address a) external view returns (uint256) {
        return _numberMinted(a);
    }

    function getStageInfo(uint256 index)
        external
        view
        returns (
            MintStageInfo memory,
            uint32,
            uint256
        )
    {
        if (index >= _mintStages.length) {
            revert("InvalidStage");
        }
        uint32 walletMinted = _stageMintedCounts[index][msg.sender];
        uint256 stageMinted = _stageMintedSupply[index];
        return (_mintStages[index], walletMinted, stageMinted);
    }

    function updateStage(
        uint256 index,
        uint256 price,
        uint32 walletLimit,
        bytes32 merkleRoot,
        uint256 maxStageSupply
    ) external onlyOwner {
        if (index >= _mintStages.length) revert InvalidStage();
        _mintStages[index].price = price;
        _mintStages[index].walletLimit = walletLimit;
        _mintStages[index].merkleRoot = merkleRoot;
        _mintStages[index].maxStageSupply = maxStageSupply;

        emit UpdateStage(index, price, walletLimit, merkleRoot, maxStageSupply);
    }

    function mint(uint32 qty, bytes32[] calldata proof)
        external
        payable
        canMint
        hasSupply(qty)
    {
        if (_activeStage >= _mintStages.length) revert InvalidStage();

        MintStageInfo memory stage = _mintStages[_activeStage];

        // Check value
        if (msg.value < stage.price * qty) revert NotEnoughValue();

        // Check stage supply if applicable
        if (stage.maxStageSupply > 0) {
            if (_stageMintedSupply[_activeStage] + qty > stage.maxStageSupply)
                revert StageSupplyExceeded();
        }

        // Check global wallet limit if applicable
        if (_globalWalletLimit > 0) {
            if (_numberMinted(msg.sender) + qty > _globalWalletLimit)
                revert WalletGlobalLimitExceeded();
        }

        // Check wallet limit for stage if applicable, limit == 0 means no limit enforced
        if (stage.walletLimit > 0) {
            if (
                _stageMintedCounts[_activeStage][msg.sender] + qty >
                stage.walletLimit
            ) revert WalletStageLimitExceeded();
        }

        // Check merkle proof if applicable, merkleRoot == 0x00...00 means no proof required
        if (stage.merkleRoot != 0) {
            if (
                MerkleProof.processProof(
                    proof,
                    keccak256(abi.encodePacked(msg.sender))
                ) != stage.merkleRoot
            ) revert InvalidProof();
        }

        _stageMintedCounts[_activeStage][msg.sender] += qty;
        _stageMintedSupply[_activeStage] += qty;
        _safeMint(msg.sender, qty);
    }

    function ownerMint(uint32 qty, address to) external onlyOwner {
        _stageMintedCounts[_activeStage][to] += qty;
        _safeMint(to, qty);
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _currentBaseURI = baseURI;
        emit SetBaseURI(baseURI);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _currentBaseURI;
        return
            bytes(baseURI).length != 0
                ? string(abi.encodePacked(baseURI, _toString(tokenId)))
                : "";
    }
}
