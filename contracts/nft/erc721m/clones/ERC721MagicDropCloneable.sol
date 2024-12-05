// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

import {IERC721A} from "erc721a/contracts/IERC721A.sol";

import {ERC721MagicDropMetadataCloneable} from "./ERC721MagicDropMetadataCloneable.sol";
import {ERC721ACloneable} from "./ERC721ACloneable.sol";
import {IERC721MagicDropMetadata} from "../interfaces/IERC721MagicDropMetadata.sol";

contract ERC721MagicDropCloneable is ERC721MagicDropMetadataCloneable, ReentrancyGuard {
    address private _payoutRecipient;
    address private _feeRecipient;
    uint256 private _mintFee;
    uint256 private _totalMintFee;

    PublicStage private _publicStage;
    AllowlistStage private _allowlistStage;

    struct PublicStage {
        uint256 startTime;
        uint256 endTime;
        uint256 price;
    }

    struct AllowlistStage {
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        bytes32 merkleRoot;
    }

    struct SetupConfig {
        uint256 maxSupply;
        uint256 walletLimit;
        string baseURI;
        string contractURI;
        PublicStage publicStage;
        AllowlistStage allowlistStage;
        address payoutRecipient;
        address feeRecipient;
        uint256 mintFee;
        bytes32 provenanceHash;
    }

    error PublicStageNotActive();
    error AllowlistStageNotActive();
    error NotEnoughValue();
    error WalletLimitExceeded();
    error WithdrawFailed();
    error InvalidProof();

    event MagicDropTokenDeployed();
    event Withdraw(uint256 amount);

    function initialize(string memory _name, string memory _symbol, address _owner) public initializer {
        __ERC721ACloneable__init(_name, _symbol);
        _initializeOwner(_owner);

        emit MagicDropTokenDeployed();
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }

    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721ACloneable, IERC721A)
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        bool isBaseURIEmpty = bytes(baseURI).length == 0;
        bool hasNoTrailingSlash = bytes(baseURI)[bytes(baseURI).length - 1] != bytes("/")[0];

        if (isBaseURIEmpty) {
            return "";
        }

        if (hasNoTrailingSlash) {
            return baseURI;
        }

        return string(abi.encodePacked(baseURI, _toString(tokenId)));
    }

    function setPublicStage(PublicStage calldata stage) external onlyOwner {
        _publicStage = stage;
    }

    function setAllowlistStage(AllowlistStage calldata stage) external onlyOwner {
        _allowlistStage = stage;
    }

    function setPayoutRecipient(address newPayoutRecipient) external onlyOwner {
        _payoutRecipient = newPayoutRecipient;
    }

    function mintPublic(uint256 qty, address to) external payable {
        PublicStage memory stage = _publicStage;
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert PublicStageNotActive();
        }

        uint256 mintFees = _mintFee * qty;

        if (msg.value < stage.price * qty + mintFees) {
            revert NotEnoughValue();
        }

        if (_numberMinted(to) + qty > this.walletLimit()) {
            revert WalletLimitExceeded();
        }

        _totalMintFee += mintFees;

        _safeMint(to, qty);
    }

    function mintAllowlist(uint256 qty, address to, bytes32[] calldata proof) external payable {
        AllowlistStage memory stage = _allowlistStage;
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert AllowlistStageNotActive();
        }

        if (!MerkleProofLib.verify(proof, stage.merkleRoot, keccak256(abi.encodePacked(to)))) {
            revert InvalidProof();
        }

        uint256 mintFees = _mintFee * qty;

        if (msg.value < stage.price * qty + mintFees) {
            revert NotEnoughValue();
        }

        if (_numberMinted(to) + qty > this.walletLimit()) {
            revert WalletLimitExceeded();
        }

        _totalMintFee += mintFees;

        _safeMint(to, qty);
    }

    function mintFee() external view returns (uint256) {
        return _mintFee;
    }

    function setup(SetupConfig calldata config) external onlyOwner {
        if (config.maxSupply > 0) {
            this.setMaxSupply(config.maxSupply);
        }

        if (config.walletLimit > 0) {
            this.setWalletLimit(config.walletLimit);
        }

        if (bytes(config.baseURI).length > 0) {
            this.setBaseURI(config.baseURI);
        }

        if (bytes(config.contractURI).length > 0) {
            this.setContractURI(config.contractURI);
        }

        if (config.publicStage.startTime != 0 || config.publicStage.endTime != 0) {
            this.setPublicStage(config.publicStage);
        }

        if (config.allowlistStage.startTime != 0 || config.allowlistStage.endTime != 0) {
            this.setAllowlistStage(config.allowlistStage);
        }

        if (config.payoutRecipient != address(0)) {
            this.setPayoutRecipient(config.payoutRecipient);
        }

        if (config.feeRecipient != address(0)) {
            _feeRecipient = config.feeRecipient;
        }

        if (config.provenanceHash != bytes32(0)) {
            this.setProvenanceHash(config.provenanceHash);
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721MagicDropMetadataCloneable)
        returns (bool)
    {
        return interfaceId == type(IERC721MagicDropMetadata).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @notice Withdraws the total mint fee and remaining balance from the contract
    /// @dev Can only be called by the owner
    function withdraw() external onlyOwner {
        (bool success,) = _feeRecipient.call{value: _totalMintFee}("");
        if (!success) revert WithdrawFailed();
        _totalMintFee = 0;

        uint256 remainingValue = address(this).balance;
        (success,) = _payoutRecipient.call{value: remainingValue}("");
        if (!success) revert WithdrawFailed();

        emit Withdraw(_totalMintFee + remainingValue);
    }

    /// @dev Overriden to prevent double-initialization of the owner.
    function _guardInitializeOwner() internal pure virtual override returns (bool) {
        return true;
    }
}
