//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "erc721a/contracts/extensions/ERC721AQueryable.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

struct MintStageInfo {
    uint256 price;
    uint32 walletLimit; // 0 for unlimited
    bytes32 merkleRoot; // 0x0 for no presale enforced
    uint256 maxStageSupply; // 0 for unlimited
}

contract ERC721M is ERC721AQueryable, Ownable {
    bool private paused;
    string private baseURI;
    MintStageInfo[] private mintStages;

    // Need this because struct cannot have nested mapping
    mapping(uint256 => mapping(address => uint32)) private stageMintedCounts;
    mapping(uint256 => uint256) private stageMintedSupply;

    uint256 private activeStage;
    uint256 private maxMintableSupply;
    uint256 private globalWalletLimit;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxMintableSupply,
        uint256 _globalWalletLimit
    ) ERC721A(_name, _symbol) {
        require(
            _globalWalletLimit <= _maxMintableSupply,
            "globalWalletLimit overflow"
        );
        paused = true;
        maxMintableSupply = _maxMintableSupply;
        globalWalletLimit = _globalWalletLimit;
    }

    modifier notPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier hasSupply(uint256 _qty) {
        require(totalSupply() + _qty <= maxMintableSupply, "No supply left");
        _;
    }

    function setStages(
        uint256[] memory prices,
        uint32[] memory walletLimits,
        bytes32[] memory merkleRoots,
        uint256[] memory maxStageSupplies
    ) external onlyOwner {
        // check all arrays are the same length
        require(
            prices.length == walletLimits.length &&
                walletLimits.length == merkleRoots.length &&
                merkleRoots.length == maxStageSupplies.length,
            "Invalid array length"
        );

        uint256 originalSize = mintStages.length;
        for (uint256 i = 0; i < originalSize; i++) {
            mintStages.pop();
        }

        for (uint256 i = 0; i < prices.length; i++) {
            mintStages.push(
                MintStageInfo({
                    price: prices[i],
                    walletLimit: walletLimits[i],
                    merkleRoot: merkleRoots[i],
                    maxStageSupply: maxStageSupplies[i]
                })
            );
        }

        // emit SetStage event
    }

    function isPaused() external view returns (bool) {
        return paused;
    }

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function getNumberStages() external view returns (uint256) {
        return mintStages.length;
    }

    function getMaxMintableSupply() external view returns (uint256) {
        return maxMintableSupply;
    }

    function setMaxMintableSupply(uint256 _maxMintableSupply)
        external
        onlyOwner
    {
        maxMintableSupply = _maxMintableSupply;
    }

    function getGlobalWalletLimit() external view returns (uint256) {
        return globalWalletLimit;
    }

    function setGlobalWalletLimit(uint256 _globalWalletLimit)
        external
        onlyOwner
    {
        require(
            _globalWalletLimit <= maxMintableSupply,
            "globalWalletLimit overflow"
        );
        globalWalletLimit = _globalWalletLimit;
    }

    function getActiveStage() external view returns (uint256) {
        return activeStage;
    }

    function setActiveStage(uint256 _activeStage) external onlyOwner {
        require(_activeStage < mintStages.length, "Invalid stage");
        activeStage = _activeStage;
    }

    function totalMintedByAddress(address _address)
        external
        view
        returns (uint256)
    {
        return _numberMinted(_address);
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
        if (index >= mintStages.length) {
            revert("Stage does not exist");
        }
        uint32 walletMinted = stageMintedCounts[index][msg.sender];
        uint256 stageMinted = stageMintedSupply[index];
        return (mintStages[index], walletMinted, stageMinted);
    }

    function updateStage(
        uint256 _index,
        uint256 price,
        uint32 walletLimit,
        bytes32 merkleRoot,
        uint256 maxStageSupply
    ) external onlyOwner {
        if (_index >= mintStages.length) {
            revert("Stage does not exist");
        }
        mintStages[_index].price = price;
        mintStages[_index].walletLimit = walletLimit;
        mintStages[_index].merkleRoot = merkleRoot;
        mintStages[_index].maxStageSupply = maxStageSupply;

        // emit UpdateStage event
    }

    function mint(uint32 _qty, bytes32[] calldata _proof)
        external
        payable
        notPaused
        hasSupply(_qty)
    {
        MintStageInfo memory stage = mintStages[activeStage];
        // Check value
        require(msg.value >= (stage.price * _qty), "Incorrect amount sent");

        // Check stage supply if applicable
        if (stage.maxStageSupply > 0) {
            require(
                stageMintedSupply[activeStage] + _qty <= stage.maxStageSupply,
                "Stage supply exceeded"
            );
        }

        // Check global wallet limit if applicable
        if (globalWalletLimit > 0) {
            require(
                _numberMinted(msg.sender) + _qty <= globalWalletLimit,
                "Global wallet limit exceeded"
            );
        }

        // Check wallet limit for stage if applicable, limit == 0 means no limit enforced
        if (stage.walletLimit > 0) {
            require(
                stageMintedCounts[activeStage][msg.sender] + _qty <=
                    stage.walletLimit,
                "Exceeds wallet limit"
            );
        }

        // Check merkle proof if applicable, merkleRoot == 0x00...00 means no proof required
        if (stage.merkleRoot != 0) {
            require(
                MerkleProof.processProof(
                    _proof,
                    keccak256(abi.encodePacked(msg.sender))
                ) == stage.merkleRoot,
                "Invalid Merkle proof"
            );
        }

        stageMintedCounts[activeStage][msg.sender] += _qty;
        stageMintedSupply[activeStage] += _qty;
        _safeMint(msg.sender, _qty);
    }

    function ownerMint(uint32 _qty, address _to) external onlyOwner {
        stageMintedCounts[activeStage][_to] += _qty;
        _safeMint(_to, _qty);
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "Invalid tokenId"
        );

        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, _toString(tokenId)))
                : "";
    }
}
