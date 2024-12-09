// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {ReentrancyGuard} from "solady/src/utils/ReentrancyGuard.sol";
import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";

import {IERC721A} from "erc721a/contracts/IERC721A.sol";

import {ERC721MagicDropMetadataCloneable} from "./ERC721MagicDropMetadataCloneable.sol";
import {ERC721ACloneable} from "./ERC721ACloneable.sol";
import {IERC721MagicDropMetadata} from "../interfaces/IERC721MagicDropMetadata.sol";
import {PublicStage, AllowlistStage, SetupConfig} from "./Types.sol";


/// @title ERC721MagicDropCloneable
/// @notice ERC721A with Public and Allowlist minting stages.
/// @dev This contract is cloneable and provides minting functionality with public and allowlist stages.
contract ERC721MagicDropCloneable is ERC721MagicDropMetadataCloneable, ReentrancyGuard {

    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    /// @dev The recipient of the mint proceeds.
    address private _payoutRecipient;

    /// @dev The recipient of extra mint fees.
    address public constant PROTOCOL_FEE_RECIPIENT = 0x0000000000000000000000000000000000000000;

    /// @dev The mint fee in basis points (bps).
    uint256 public constant PROTOCOL_FEE_BPS = 500; // 5%

    /// @dev The denominator for basis points (bps).
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @dev Storage for the public mint stage.
    PublicStage private _publicStage;

    /// @dev Storage for the allowlist mint stage.
    AllowlistStage private _allowlistStage;

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    /// @notice Emitted when the token is deployed.
    event MagicDropTokenDeployed();

    /// @notice Emitted when the funds are withdrawn.
    event Withdraw(uint256 amount);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    /// @notice Thrown when the public mint stage is not active.
    error PublicStageNotActive();

    /// @notice Thrown when the allowlist mint stage is not active.
    error AllowlistStageNotActive();

    /// @notice Thrown when the user does not send enough value.
    error NotEnoughValue();

    /// @notice Thrown when the wallet limit is exceeded.
    error WalletLimitExceeded();

    /// @notice Thrown when the withdraw fails.
    error WithdrawFailed();

    /// @notice Thrown when the proof is invalid.
    error InvalidProof();

    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @notice Initializes the contract.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _owner The owner of the contract.
    function initialize(string memory _name, string memory _symbol, address _owner) public initializer {
        __ERC721ACloneable__init(_name, _symbol);
        _initializeOwner(_owner);

        emit MagicDropTokenDeployed();
    }

    /*==============================================================
    =                     PUBLIC WRITE METHODS                     =
    ==============================================================*/

    /// @notice Mints tokens to the specified address.
    /// @param qty The quantity of tokens to mint.
    /// @param to The address to mint the tokens to.
    function mintPublic(uint256 qty, address to) external payable {
        PublicStage memory stage = _publicStage;
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert PublicStageNotActive();
        }

        if (msg.value < stage.price * qty) {
            revert NotEnoughValue();
        }

        if (_numberMinted(to) + qty > this.walletLimit()) {
            revert WalletLimitExceeded();
        }

        _safeMint(to, qty);
    }

    /// @notice Mints tokens to the specified address.
    /// @param qty The quantity of tokens to mint.
    /// @param to The address to mint the tokens to.
    /// @param proof The Merkle proof for the allowlist mint stage.
    function mintAllowlist(uint256 qty, address to, bytes32[] calldata proof) external payable {
        AllowlistStage memory stage = _allowlistStage;
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert AllowlistStageNotActive();
        }

        if (!MerkleProofLib.verify(proof, stage.merkleRoot, keccak256(abi.encodePacked(to)))) {
            revert InvalidProof();
        }

        if (msg.value < stage.price * qty) {
            revert NotEnoughValue();
        }

        if (_numberMinted(to) + qty > this.walletLimit()) {
            revert WalletLimitExceeded();
        }

        _safeMint(to, qty);
    }

    /// @notice Burns a token.
    /// @param tokenId The token ID to burn.
    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Gets the public mint stage.
    /// @return The public mint stage.
    function getPublicStage() external view returns (PublicStage memory) {
        return _publicStage;
    }

    /// @notice Gets the allowlist mint stage.
    /// @return The allowlist mint stage.
    function getAllowlistStage() external view returns (AllowlistStage memory) {
        return _allowlistStage;
    }

    /// @notice Gets the payout recipient.
    /// @return The payout recipient.
    function payoutRecipient() external view returns (address) {
        return _payoutRecipient;
    }

    /// @notice Gets the fee recipient.
    /// @return The fee recipient.
    function feeRecipient() external view returns (address) {
        return _feeRecipient;
    }

    /// @notice Supports the ERC721MagicDropMetadata interface.
    /// @param interfaceId The interface ID.
    /// @return True if the interface is supported, false otherwise.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721MagicDropMetadataCloneable)
        returns (bool)
    {
        return interfaceId == type(IERC721MagicDropMetadata).interfaceId || super.supportsInterface(interfaceId);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Configures the contract with the provided setup parameters.
    /// @param config The configuration parameters for setting up the contract.
    function setup(SetupConfig calldata config) external onlyOwner {
        if (config.maxSupply > 0) {
            this.setMaxSupply(config.maxSupply);
        }

        // A wallet limit of 0 means unlimited mints per wallet
        // Otherwise, wallets can only mint up to the specified limit
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

    /// @notice Sets the public mint stage.
    /// @param stage The configuration for the public mint stage.
    function setPublicStage(PublicStage calldata stage) external onlyOwner {
        _publicStage = stage;
    }

    /// @notice Sets the allowlist mint stage.
    /// @param stage The configuration for the allowlist mint stage.
    function setAllowlistStage(AllowlistStage calldata stage) external onlyOwner {
        _allowlistStage = stage;
    }

    /// @notice Sets the payout recipient.
    /// @param newPayoutRecipient The address to receive the payout from mint proceeds.
    function setPayoutRecipient(address newPayoutRecipient) external onlyOwner {
        _payoutRecipient = newPayoutRecipient;
    }

    /// @notice Withdraws the total mint fee and remaining balance from the contract
    /// @dev Can only be called by the owner
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        uint256 protocolFee = (balance * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
        uint256 remainingBalance = balance - protocolFee;

        // Transfer protocol fee
        (bool feeSuccess,) = PROTOCOL_FEE_RECIPIENT.call{value: protocolFee}("");
        if (!feeSuccess) revert WithdrawFailed();

        // Transfer remaining balance to the payout recipient
        (bool success,) = _payoutRecipient.call{value: remainingBalance}("");
        if (!success) revert WithdrawFailed();

        emit Withdraw(balance);
    }

    /*==============================================================
    =                             META                             =
    ==============================================================*/

    /// @notice Returns the contract name and version
    /// @return The contract name and version as strings
    function contractNameAndVersion() public pure returns (string memory, string memory) {
        return ("ERC721MagicDropCloneable", "1.0.0");
    }


    /// @notice Gets the token URI for a given token ID.
    /// @param tokenId The token ID.
    /// @return The token URI.
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

    /// @dev Overriden to prevent double-initialization of the owner.
    function _guardInitializeOwner() internal pure virtual override returns (bool) {
        return true;
    }

    /// @notice Gets the starting token ID.
    /// @return The starting token ID.
    function _startTokenId() internal view virtual override returns (uint256) {
        return 1;
    }
}
