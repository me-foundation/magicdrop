// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {MerkleProofLib} from "solady/src/utils/MerkleProofLib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {ERC1155MagicDropMetadataCloneable} from "./ERC1155MagicDropMetadataCloneable.sol";
import {ERC1155ConduitPreapprovedCloneable} from "./ERC1155ConduitPreapprovedCloneable.sol";
import {PublicStage, AllowlistStage, SetupConfig} from "./Types.sol";
import {IERC1155MagicDropMetadata} from "../interfaces/IERC1155MagicDropMetadata.sol";

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
/// @title ERC1155MagicDropCloneable
/// @notice A cloneable ERC-1155 drop contract that supports both a public minting stage and an allowlist minting stage.
/// @dev This contract extends metadata configuration, ownership, and royalty support from its parent, while adding
///      time-gated, price-defined minting stages. It also incorporates a payout recipient and protocol fee structure.
contract ERC1155MagicDropCloneable is ERC1155MagicDropMetadataCloneable {
    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    /// @dev Address that receives the primary sale proceeds of minted tokens.
    ///      Configurable by the owner. If unset, withdrawals may fail.
    address internal _payoutRecipient;

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
    mapping(uint256 => PublicStage) internal _publicStages; // tokenId => publicStage

    /// @dev Configuration of the allowlist mint stage, including timing, price, and a merkle root for verification.
    /// @notice Only addresses proven by a valid Merkle proof can mint during this stage.
    mapping(uint256 => AllowlistStage) internal _allowlistStages; // tokenId => allowlistStage

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
    error NotEnoughValue();

    /// @notice Thrown when the provided Merkle proof for an allowlist mint is invalid.
    error InvalidProof();

    /// @notice Thrown when a stage's start or end time configuration is invalid.
    error InvalidStageTime();

    /// @notice Thrown when the public stage timing conflicts with the allowlist stage timing.
    error InvalidPublicStageTime();

    /// @notice Thrown when the allowlist stage timing conflicts with the public stage timing.
    error InvalidAllowlistStageTime();

    /// @notice Thrown when the payout recipient is set to a zero address.
    error PayoutRecipientCannotBeZeroAddress();

    /*==============================================================
    =                          INITIALIZERS                        =
    ==============================================================*/

    /// @notice Initializes the contract with a name, symbol, and owner.
    /// @dev Can only be called once. It sets the owner, emits a deploy event, and prepares the token for minting stages.
    /// @param _name The ERC-1155 name of the collection.
    /// @param _symbol The ERC-1155 symbol of the collection.
    /// @param _owner The address designated as the initial owner of the contract.
    function initialize(string memory _name, string memory _symbol, address _owner) public initializer {
        __ERC1155MagicDropMetadataCloneable__init(_name, _symbol, _owner);
    }

    /*==============================================================
    =                     PUBLIC WRITE METHODS                     =
    ==============================================================*/

    /// @notice Mints tokens during the public stage.
    /// @dev Requires that the current time is within the configured public stage interval.
    ///      Reverts if the buyer does not send enough ETH, or if the wallet limit would be exceeded.
    /// @param to The recipient address for the minted tokens.
    /// @param tokenId The ID of the token to mint.
    /// @param qty The number of tokens to mint.
    function mintPublic(address to, uint256 tokenId, uint256 qty, bytes memory data) external payable {
        PublicStage memory stage = _publicStages[tokenId];
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert PublicStageNotActive();
        }

        uint256 requiredPayment = stage.price * qty;
        if (msg.value < requiredPayment) {
            revert NotEnoughValue();
        }

        if (_walletLimit[tokenId] > 0 && _totalMintedByUserPerToken[to][tokenId] + qty > _walletLimit[tokenId]) {
            revert WalletLimitExceeded(tokenId);
        }

        _increaseSupplyOnMint(to, tokenId, qty);

        _mint(to, tokenId, qty, data);

        if (stage.price != 0) {
            _splitProceeds();
        }

        emit TokenMinted(to, tokenId, qty);
    }

    /// @notice Mints tokens during the allowlist stage.
    /// @dev Requires a valid Merkle proof and the current time within the allowlist stage interval.
    ///      Reverts if the buyer sends insufficient ETH or if the wallet limit is exceeded.
    /// @param to The recipient address for the minted tokens.
    /// @param tokenId The ID of the token to mint.
    /// @param qty The number of tokens to mint.
    /// @param proof The Merkle proof verifying `to` is eligible for the allowlist.
    function mintAllowlist(address to, uint256 tokenId, uint256 qty, bytes32[] calldata proof, bytes memory data)
        external
        payable
    {
        AllowlistStage memory stage = _allowlistStages[tokenId];
        if (block.timestamp < stage.startTime || block.timestamp > stage.endTime) {
            revert AllowlistStageNotActive();
        }

        if (!MerkleProofLib.verify(proof, stage.merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(to)))))) {
            revert InvalidProof();
        }

        uint256 requiredPayment = stage.price * qty;
        if (msg.value < requiredPayment) {
            revert NotEnoughValue();
        }

        if (_walletLimit[tokenId] > 0 && _totalMintedByUserPerToken[to][tokenId] + qty > _walletLimit[tokenId]) {
            revert WalletLimitExceeded(tokenId);
        }

        _increaseSupplyOnMint(to, tokenId, qty);

        if (stage.price != 0) {
            _splitProceeds();
        }

        _mint(to, tokenId, qty, data);
        emit TokenMinted(to, tokenId, qty);
    }

    /// @notice Burns a specific quantity of tokens on behalf of a given address.
    /// @dev Reduces the total supply and calls the internal `_burn` function.
    /// @param by The address initiating the burn. Must be an approved operator or the owner of the tokens.
    /// @param from The address from which the tokens will be burned.
    /// @param id The ID of the token to burn.
    /// @param qty The quantity of tokens to burn.
    function burn(address by, address from, uint256 id, uint256 qty) external {
        _reduceSupplyOnBurn(id, qty);
        _burn(by, from, id, qty);
    }

    /// @notice Burns multiple types of tokens in a single batch operation.
    /// @dev Iterates over each token ID and quantity to reduce supply and burn tokens.
    /// @param by The address initiating the batch burn.
    /// @param from The address from which the tokens will be burned.
    /// @param ids An array of token IDs to burn.
    /// @param qty An array of quantities corresponding to each token ID to burn.
    function batchBurn(address by, address from, uint256[] calldata ids, uint256[] calldata qty) external {
        uint256 length = ids.length;
        for (uint256 i = 0; i < length;) {
            _reduceSupplyOnBurn(ids[i], qty[i]);
            unchecked {
                ++i;
            }
        }

        _batchBurn(by, from, ids, qty);
    }

    /*==============================================================
    =                     PUBLIC VIEW METHODS                      =
    ==============================================================*/

    /// @notice Returns the current configuration of the contract.
    /// @return The current configuration of the contract.
    function getConfig(uint256 tokenId) external view returns (SetupConfig memory) {
        SetupConfig memory newConfig = SetupConfig({
            tokenId: tokenId,
            maxSupply: _tokenSupply[tokenId].maxSupply,
            walletLimit: _walletLimit[tokenId],
            baseURI: _baseURI,
            contractURI: _contractURI,
            allowlistStage: _allowlistStages[tokenId],
            publicStage: _publicStages[tokenId],
            payoutRecipient: _payoutRecipient,
            royaltyRecipient: _royaltyReceiver,
            royaltyBps: _royaltyBps
        });

        return newConfig;
    }

    /// @notice Returns the current public stage configuration (startTime, endTime, price).
    /// @return The current public stage settings.
    function getPublicStage(uint256 tokenId) external view returns (PublicStage memory) {
        return _publicStages[tokenId];
    }

    /// @notice Returns the current allowlist stage configuration (startTime, endTime, price, merkleRoot).
    /// @return The current allowlist stage settings.
    function getAllowlistStage(uint256 tokenId) external view returns (AllowlistStage memory) {
        return _allowlistStages[tokenId];
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
        override(ERC1155MagicDropMetadataCloneable)
        returns (bool)
    {
        return interfaceId == type(IERC1155MagicDropMetadata).interfaceId || super.supportsInterface(interfaceId);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @notice Sets up the contract parameters in a single call.
    /// @dev Only callable by the owner. Configures max supply, wallet limit, URIs, stages, payout recipient.
    /// @param config A struct containing all setup parameters.
    function setup(SetupConfig calldata config) external onlyOwner {
        if (config.maxSupply > 0) {
            _setMaxSupply(config.tokenId, config.maxSupply);
        }

        if (config.walletLimit > 0) {
            _setWalletLimit(config.tokenId, config.walletLimit);
        }

        if (bytes(config.baseURI).length > 0) {
            _setBaseURI(config.baseURI);
        }

        if (bytes(config.contractURI).length > 0) {
            _setContractURI(config.contractURI);
        }

        if (config.allowlistStage.startTime != 0 || config.allowlistStage.endTime != 0) {
            _setAllowlistStage(config.tokenId, config.allowlistStage);
        }

        if (config.publicStage.startTime != 0 || config.publicStage.endTime != 0) {
            _setPublicStage(config.tokenId, config.publicStage);
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
    function setPublicStage(uint256 tokenId, PublicStage calldata stage) external onlyOwner {
        _setPublicStage(tokenId, stage);
    }

    /// @notice Sets the configuration of the allowlist mint stage.
    /// @dev Only callable by the owner. Ensures the allowlist stage does not overlap improperly with the public stage.
    /// @param stage A struct defining the allowlist stage timing, price, and merkle root.
    function setAllowlistStage(uint256 tokenId, AllowlistStage calldata stage) external onlyOwner {
        _setAllowlistStage(tokenId, stage);
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
    function _setPublicStage(uint256 tokenId, PublicStage calldata stage) internal {
        if (stage.startTime >= stage.endTime) {
            revert InvalidStageTime();
        }

        // Ensure the public stage starts after the allowlist stage ends
        if (_allowlistStages[tokenId].startTime != 0 && _allowlistStages[tokenId].endTime != 0) {
            if (stage.startTime <= _allowlistStages[tokenId].endTime) {
                revert InvalidPublicStageTime();
            }
        }

        _publicStages[tokenId] = stage;
        emit PublicStageSet(stage);
    }

    /// @notice Internal function to set the allowlist mint stage configuration.
    /// @dev Reverts if timing is invalid or conflicts with the public stage.
    /// @param tokenId The ID of the token to set the allowlist stage for.
    /// @param stage A struct defining allowlist stage timings, price, and merkle root.
    function _setAllowlistStage(uint256 tokenId, AllowlistStage calldata stage) internal {
        if (stage.startTime >= stage.endTime) {
            revert InvalidStageTime();
        }

        // Ensure the public stage starts after the allowlist stage ends
        if (_publicStages[tokenId].startTime != 0 && _publicStages[tokenId].endTime != 0) {
            if (stage.endTime >= _publicStages[tokenId].startTime) {
                revert InvalidAllowlistStageTime();
            }
        }

        _allowlistStages[tokenId] = stage;
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
    /// @dev This function is called by the mint functions to split the proceeds into a protocol fee and a payout.
    function _splitProceeds() internal {
        if (_payoutRecipient == address(0)) {
            revert PayoutRecipientCannotBeZeroAddress();
        }

        if (PROTOCOL_FEE_BPS > 0) {
            uint256 protocolFee = (msg.value * PROTOCOL_FEE_BPS) / BPS_DENOMINATOR;
            uint256 remainingBalance;
            unchecked {
                remainingBalance = msg.value - protocolFee;
            }
            SafeTransferLib.safeTransferETH(PROTOCOL_FEE_RECIPIENT, protocolFee);
            SafeTransferLib.safeTransferETH(_payoutRecipient, remainingBalance);
        } else {
            SafeTransferLib.safeTransferETH(_payoutRecipient, msg.value);
        }
    }

    /// @notice Internal function to reduce the total supply when tokens are burned.
    /// @dev Decreases the `totalSupply` for a given `tokenId` by the specified `qty`.
    ///      Uses `unchecked` to save gas, assuming that underflow is impossible
    ///      because burn operations should not exceed the current supply.
    /// @param tokenId The ID of the token being burned.
    /// @param qty The quantity of tokens to burn.
    function _reduceSupplyOnBurn(uint256 tokenId, uint256 qty) internal {
        TokenSupply storage supply = _tokenSupply[tokenId];
        unchecked {
            supply.totalSupply -= uint64(qty);
        }
    }

    /// @notice Internal function to increase the total supply when tokens are minted.
    /// @dev Increases the `totalSupply` and `totalMinted` for a given `tokenId` by the specified `qty`.
    ///      Ensures that the new total minted amount does not exceed the `maxSupply`.
    ///      Uses `unchecked` to save gas, assuming that overflow is impossible
    ///      because the maximum values are constrained by `maxSupply`.
    /// @param to The address receiving the minted tokens.
    /// @param tokenId The ID of the token being minted.
    /// @param qty The quantity of tokens to mint.
    /// @custom:reverts {CannotExceedMaxSupply} If the minting would exceed the maximum supply for the `tokenId`.
    function _increaseSupplyOnMint(address to, uint256 tokenId, uint256 qty) internal {
        TokenSupply storage supply = _tokenSupply[tokenId];

        if (supply.totalMinted + qty > supply.maxSupply) {
            revert CannotExceedMaxSupply();
        }

        unchecked {
            supply.totalSupply += uint64(qty);
            supply.totalMinted += uint64(qty);
            _totalMintedByUserPerToken[to][tokenId] += uint64(qty);
        }
    }

    /*==============================================================
    =                             META                             =
    ==============================================================*/

    /// @notice Returns the contract name and version.
    /// @dev Useful for external tools or metadata standards.
    /// @return The contract name and version strings.
    function contractNameAndVersion() public pure returns (string memory, string memory) {
        return ("ERC1155MagicDropCloneable", "1.0.0");
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
