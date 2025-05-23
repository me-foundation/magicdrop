// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {IERC721A} from "erc721a/contracts/IERC721A.sol";

import {ERC721MagicDropMetadataCloneable} from "./ERC721MagicDropMetadataCloneable.sol";
import {ERC721ACloneable} from "./ERC721ACloneable.sol";
import {IERC721MagicDropMetadata} from "../interfaces/IERC721MagicDropMetadata.sol";
import {PublicStage, AllowlistStage, SetupConfig} from "./Types.sol";

import {SELF_SERVE_MINT_FEE_RECEIVER} from "../../../utils/Constants.sol";

///                                                     ........
///                             .....                   ..    ...
///                            ..    .....             ..     ..
///                            ..  ... .....           ..     ..
///                            ..  ......  ..          ...... ..
///                             ..   .........     .........  ....
///                             ....        ..   ..        ...
///                                ........  .........     ..
///                                    ..       ...  ...  ..       .........
///                                  ..    ..........  ....    .... ....... ........
///                                  .......     .. ..  ...    .... .....          ..
///                                                ........  .    ...  ..             ..
///                    .                       .....       ........     ....          ..
///                  .. ..                  ...              ...........   ...     ...
///               .......                 ..  ......                  ...          ..
///              ............           ...  ........                   ..          ..
///              ...  ..... ..        ..   ..    ..                     ..  ......
///          .. ........    ...     ..    ..   ..                ....   ....
///          .......         ..   ..     ......                .......    ..
///              ..           .....                            .. ....     ..
///              ..           ....    .........                .    ..     ..
///                ...       ....    ..       .........        .    ..     ..
///                  ....   ....     ..              .....     ......      ...
///                       .....      ..   ........         ...             ...
///                        ...       .. ..       .. ......   .....         ..
///                        ..         ....        ...    ...     ..        ..
///                       ..           ....                ..    ..        ..
///                       .              ......             ..  ..         ..
///                      ..                ......................         ..............
///                      ..                   ................           ....          ...
///                      .                                              ...           ........
///                       ..                                             ...          ......  ..
///                        ..                                            ....        ...EMMY....
///                         ..                                           .. ...     ....  .... ..
///                           ..                                         ..    ..... ..........
///                            ...                                      ..          ... ......
///                          ... ....                                  ..                 ..
///                         ..      .....                            ...
///                       .....          ....     ........         ...
///                       ........        .. .....       ..........
///                       .. ........    ..    ..MAGIC.....  .
///                        ....       ....    ....  ..EDEN....
///                             .....         . ...     ......
///                                           ..   .......  ..
///                                            .....    .....
///                                                  ....
/// @title ERC721MagicDropCloneable
/// @notice A cloneable ERC-721A drop contract that supports both a public minting stage and an allowlist minting stage.
/// @dev This contract extends metadata configuration, ownership, and royalty support from its parent, while adding
///      time-gated, price-defined minting stages. It also incorporates a payout recipient and protocol fee structure.
contract ERC721MagicDropCloneable is ERC721MagicDropMetadataCloneable {
    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    /// @dev Address that receives the primary sale proceeds of minted tokens.
    ///      Configurable by the owner. If unset, withdrawals may fail.
    address private _payoutRecipient;

    /// @dev The address that receives protocol fees on withdrawal.
    /// @notice This is fixed and cannot be changed.
    address public constant PROTOCOL_FEE_RECIPIENT = 0xA3833016a4eC61f5c253D71c77522cC8A1cC1106;

    /// @dev The protocol fee expressed in basis points (e.g., 500 = 5%).
    /// @notice This fee is taken from the contract's entire balance upon withdrawal.
    uint256 public constant PROTOCOL_FEE_BPS = 0; // 0%

    /// @dev The denominator used for calculating basis points.
    /// @notice 10,000 BPS = 100%. A fee of 500 BPS is therefore 5%.
    uint256 public constant BPS_DENOMINATOR = 10_000;

    /// @dev Configuration of the public mint stage, including timing and price.
    /// @notice Public mints occur only if the current timestamp is within [startTime, endTime].
    PublicStage private _publicStage;

    /// @dev Configuration of the allowlist mint stage, including timing, price, and a merkle root for verification.
    /// @notice Only addresses proven by a valid Merkle proof can mint during this stage.
    AllowlistStage private _allowlistStage;

    /// @dev The mint fee to charge on top of each mint
    /// @notice Set permanently on initialization
    uint256 public mintFee;

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    /// @notice Emitted when the public mint stage is set.
    event PublicStageSet(PublicStage stage);

    /// @notice Emitted when the allowlist mint stage is set.
    event AllowlistStageSet(AllowlistStage stage);

    /// @notice Emitted when the payout recipient is set.
    event PayoutRecipientSet(address newPayoutRecipient);

    /// @notice Emitted when a token is minted.
    event TokenMinted(address indexed to, uint256 tokenId, uint256 qty);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    /// @notice Thrown when attempting to mint during a public stage that is not currently active.
    error PublicStageNotActive();

    /// @notice Thrown when attempting to mint during an allowlist stage that is not currently active.
    error AllowlistStageNotActive();

    /// @notice Thrown when the provided ETH value for a mint is insufficient.
    error RequiredValueNotMet();

    /// @notice Thrown when the provided Merkle proof for an allowlist mint is invalid.
    error InvalidProof();

    /// @notice Thrown when a stage's start or end time configuration is invalid.
    error InvalidStageTime();

    /// @notice Thrown when the allowlist stage timing conflicts with the public stage timing.
    error InvalidAllowlistStageTime();

    /// @notice Thrown when the public stage timing conflicts with the allowlist stage timing.
    error InvalidPublicStageTime();

    /// @notice Thrown when the payout recipient is set to a zero address.
    error PayoutRecipientCannotBeZeroAddress();

    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @notice Initializes the contract with a name, symbol, owner and mintFee.
    /// @dev Can only be called once. It sets the owner, emits a deploy event, and prepares the token for minting stages.
    /// @param _name The ERC-721 name of the collection.
    /// @param _symbol The ERC-721 symbol of the collection.
    /// @param _owner The address designated as the initial owner of the contract.
    /// @param _mintFee The fee to charge on top of each mint.
    function initialize(string memory _name, string memory _symbol, address _owner, uint256 _mintFee)
        public
        initializer
    {
        __ERC721ACloneable__init(_name, _symbol);
        __ERC721MagicDropMetadataCloneable__init(_owner);
        mintFee = _mintFee;
    }

    /*==============================================================
    =                     PUBLIC WRITE METHODS                     =
    ==============================================================*/

    /// @notice Mints tokens during the public stage.
    /// @dev Requires that the current time is within the configured public stage interval.
    ///      Reverts if the buyer does not send enough ETH, or if the wallet limit would be exceeded.
    /// @param to The recipient address for the minted tokens.
    /// @param qty The number of tokens to mint.
    function mintPublic(address to, uint256 qty) external payable {
        PublicStage memory stage = _publicStage;
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert PublicStageNotActive();
        }

        uint256 stagePrice = stage.price + mintFee;
        uint256 requiredPayment = stagePrice * qty;
        if (msg.value != requiredPayment) {
            revert RequiredValueNotMet();
        }

        if (_walletLimit > 0 && _numberMinted(to) + qty > _walletLimit) {
            revert WalletLimitExceeded();
        }

        if (_totalMinted() + qty > _maxSupply) {
            revert CannotExceedMaxSupply();
        }

        _safeMint(to, qty);

        if (stagePrice != 0) {
            _splitProceeds(qty);
        }

        emit TokenMinted(to, _totalMinted(), qty);
    }

    /// @notice Mints tokens during the allowlist stage.
    /// @dev Requires a valid Merkle proof and the current time within the allowlist stage interval.
    ///      Reverts if the buyer sends insufficient ETH or if the wallet limit is exceeded.
    /// @param to The recipient address for the minted tokens.
    /// @param qty The number of tokens to mint.
    /// @param proof The Merkle proof verifying `to` is eligible for the allowlist.
    function mintAllowlist(address to, uint256 qty, bytes32[] calldata proof) external payable {
        AllowlistStage memory stage = _allowlistStage;
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert AllowlistStageNotActive();
        }

        if (!MerkleProofLib.verify(proof, stage.merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(to)))))) {
            revert InvalidProof();
        }

        uint256 stagePrice = stage.price + mintFee;
        uint256 requiredPayment = stagePrice * qty;
        if (msg.value != requiredPayment) {
            revert RequiredValueNotMet();
        }

        if (_walletLimit > 0 && _numberMinted(to) + qty > _walletLimit) {
            revert WalletLimitExceeded();
        }

        if (_totalMinted() + qty > _maxSupply) {
            revert CannotExceedMaxSupply();
        }

        _safeMint(to, qty);

        if (stagePrice != 0) {
            _splitProceeds(qty);
        }
    }

    /// @notice Burns a specific token.
    /// @dev Only callable by the token owner or an approved operator. The token must exist.
    /// @param tokenId The ID of the token to burn.
    function burn(uint256 tokenId) external {
        _burn(tokenId, true);
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Returns the current configuration of the contract.
    /// @return The current configuration of the contract.
    function getConfig() external view returns (SetupConfig memory) {
        SetupConfig memory newConfig = SetupConfig({
            maxSupply: _maxSupply,
            walletLimit: _walletLimit,
            baseURI: _baseURI(),
            contractURI: _contractURI,
            allowlistStage: _allowlistStage,
            publicStage: _publicStage,
            payoutRecipient: _payoutRecipient,
            royaltyRecipient: _royaltyReceiver,
            royaltyBps: _royaltyBps
        });

        return newConfig;
    }

    /// @notice Returns the current public stage configuration (startTime, endTime, price).
    /// @return The current public stage settings.
    function getPublicStage() external view returns (PublicStage memory) {
        return _publicStage;
    }

    /// @notice Returns the current allowlist stage configuration (startTime, endTime, price, merkleRoot).
    /// @return The current allowlist stage settings.
    function getAllowlistStage() external view returns (AllowlistStage memory) {
        return _allowlistStage;
    }

    /// @notice Returns the current payout recipient who receives primary sales proceeds after protocol fees.
    /// @return The address currently set to receive payout funds.
    function payoutRecipient() external view returns (address) {
        return _payoutRecipient;
    }

    /// @notice Indicates whether the contract implements a given interface.
    /// @param interfaceId The interface ID to check for support.
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

    /// @notice Sets up the contract parameters in a single call.
    /// @dev Only callable by the owner. Configures max supply, wallet limit, URIs, stages, payout recipient.
    /// @param config A struct containing all setup parameters.
    function setup(SetupConfig calldata config) external onlyOwner {
        if (config.maxSupply > 0) {
            _setMaxSupply(config.maxSupply);
        }

        if (config.walletLimit > 0) {
            _setWalletLimit(config.walletLimit);
        }

        if (bytes(config.baseURI).length > 0) {
            _setBaseURI(config.baseURI);
        }

        if (bytes(config.contractURI).length > 0) {
            _setContractURI(config.contractURI);
        }

        if (config.allowlistStage.startTime != 0 || config.allowlistStage.endTime != 0) {
            _setAllowlistStage(config.allowlistStage);
        }

        if (config.publicStage.startTime != 0 || config.publicStage.endTime != 0) {
            _setPublicStage(config.publicStage);
        }

        if (config.payoutRecipient != address(0)) {
            _setPayoutRecipient(config.payoutRecipient);
        }

        if (config.royaltyRecipient != address(0)) {
            _setRoyaltyInfo(config.royaltyRecipient, config.royaltyBps);
        }
    }

    /// @notice Sets the configuration of the public mint stage.
    /// @dev Only callable by the owner. Ensures the public stage does not overlap improperly with the allowlist stage.
    /// @param stage A struct defining the public stage timing and price.
    function setPublicStage(PublicStage calldata stage) external onlyOwner {
        _setPublicStage(stage);
    }

    /// @notice Sets the configuration of the allowlist mint stage.
    /// @dev Only callable by the owner. Ensures the allowlist stage does not overlap improperly with the public stage.
    /// @param stage A struct defining the allowlist stage timing, price, and merkle root.
    function setAllowlistStage(AllowlistStage calldata stage) external onlyOwner {
        _setAllowlistStage(stage);
    }

    /// @notice Sets the payout recipient address for primary sale proceeds (after the protocol fee is deducted).
    /// @dev Only callable by the owner.
    /// @param newPayoutRecipient The address to receive future withdrawals.
    function setPayoutRecipient(address newPayoutRecipient) external onlyOwner {
        _setPayoutRecipient(newPayoutRecipient);
    }

    /*==============================================================
    =                      INTERNAL HELPERS                        =
    ==============================================================*/

    /// @notice Internal function to set the public mint stage configuration.
    /// @dev Reverts if timing is invalid or conflicts with the allowlist stage.
    /// @param stage A struct defining public stage timings and price.
    function _setPublicStage(PublicStage calldata stage) internal {
        if (stage.startTime >= stage.endTime) {
            revert InvalidStageTime();
        }

        // Ensure the public stage starts after the allowlist stage ends
        if (_allowlistStage.startTime != 0 && _allowlistStage.endTime != 0) {
            if (stage.startTime <= _allowlistStage.endTime) {
                revert InvalidPublicStageTime();
            }
        }

        _publicStage = stage;
        emit PublicStageSet(stage);
    }

    /// @notice Internal function to set the allowlist mint stage configuration.
    /// @dev Reverts if timing is invalid or conflicts with the public stage.
    /// @param stage A struct defining allowlist stage timings, price, and merkle root.
    function _setAllowlistStage(AllowlistStage calldata stage) internal {
        if (stage.startTime >= stage.endTime) {
            revert InvalidStageTime();
        }

        // Ensure the public stage starts after the allowlist stage ends
        if (_publicStage.startTime != 0 && _publicStage.endTime != 0) {
            if (stage.endTime >= _publicStage.startTime) {
                revert InvalidAllowlistStageTime();
            }
        }

        _allowlistStage = stage;
        emit AllowlistStageSet(stage);
    }

    /// @notice Internal function to set the payout recipient.
    /// @dev This function does not revert if given a zero address, but no payouts would succeed if so.
    /// @param newPayoutRecipient The address to receive the payout from mint proceeds.
    function _setPayoutRecipient(address newPayoutRecipient) internal {
        _payoutRecipient = newPayoutRecipient;
        emit PayoutRecipientSet(newPayoutRecipient);
    }

    /// @notice Internal function to split the proceeds of a mint.
    /// @dev This function is called by the mint functions to split the proceeds into a mint fee, protocol fee and a payout.
    function _splitProceeds(uint256 qty) internal {
        if (_payoutRecipient == address(0)) {
            revert PayoutRecipientCannotBeZeroAddress();
        }

        uint256 proceeds = msg.value;

        if (mintFee > 0) {
            uint256 totalMintFee = mintFee * qty;
            proceeds -= totalMintFee;
            SafeTransferLib.safeTransferETH(SELF_SERVE_MINT_FEE_RECEIVER, totalMintFee);
        }

        // If there are no remaining proceeds after mint fee is taken, exit early
        if (proceeds == 0) {
            return;
        }

        if (PROTOCOL_FEE_BPS > 0) {
            uint256 protocolFee = (proceeds * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
            uint256 remainingBalance;
            unchecked {
                remainingBalance = proceeds - protocolFee;
            }
            SafeTransferLib.safeTransferETH(PROTOCOL_FEE_RECIPIENT, protocolFee);
            SafeTransferLib.safeTransferETH(_payoutRecipient, remainingBalance);
        } else {
            SafeTransferLib.safeTransferETH(_payoutRecipient, proceeds);
        }
    }

    /*==============================================================
    =                             META                             =
    ==============================================================*/

    /// @notice Returns the contract name and version.
    /// @dev Useful for external tools or metadata standards.
    /// @return The contract name and version strings.
    function contractNameAndVersion() public pure returns (string memory, string memory) {
        return ("ERC721MagicDropCloneable", "1.0.2");
    }

    /// @notice Retrieves the token metadata URI for a given token ID.
    /// @dev If no base URI is set, returns an empty string.
    ///      If a trailing slash is present, tokenId is appended; otherwise returns just the base URI.
    /// @param tokenId The ID of the token to retrieve the URI for.
    /// @return The token's metadata URI as a string.
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
        bool hasNoTrailingSlash = !isBaseURIEmpty && bytes(baseURI)[bytes(baseURI).length - 1] != bytes("/")[0];

        if (isBaseURIEmpty) {
            return "";
        }
        if (hasNoTrailingSlash) {
            return baseURI;
        }

        return string(abi.encodePacked(baseURI, _toString(tokenId)));
    }

    /*==============================================================
    =                             MISC                             =
    ==============================================================*/

    /// @dev Overridden to allow this contract to properly manage owner initialization.
    ///      By always returning true, we ensure that the inherited initializer does not re-run.
    function _guardInitializeOwner() internal pure virtual override returns (bool) {
        return true;
    }
}
