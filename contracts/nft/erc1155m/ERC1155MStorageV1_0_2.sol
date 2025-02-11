// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {MintStageInfo1155} from "contracts/nft/erc1155m/Types.sol";

contract ERC1155MStorageV1_0_2 {
    // Mint stage information. See MintStageInfo1155 for details.
    MintStageInfo1155[] internal _mintStages;

    // The name of the token
    string public name;

    // The symbol of the token
    string public symbol;

    // Whether the token can be transferred.
    bool internal _transferable;

    // The total mintable supply per token.
    uint256[] internal _maxMintableSupply;

    // Global wallet limit, across all stages, per token.
    uint256[] internal _globalWalletLimit;

    // Total mint fee
    uint256 internal _totalMintFee;

    // Address of ERC-20 token used to pay for minting. If 0 address, use native currency.
    address internal _mintCurrency;

    // Number of tokens
    uint256 internal _numTokens;

    // Fund receiver
    address internal _fundReceiver;

    // Whether the contract has been setup.
    bool internal _setupLocked;

    // Royalty recipient
    address internal _royaltyRecipient;

    // Royalty basis points
    uint96 internal _royaltyBps;

    // Contract uri
    string internal _contractURI;

    // Minted count per stage per token per wallet.
    mapping(uint256 => mapping(uint256 => mapping(address => uint32))) internal _stageMintedCountsPerTokenPerWallet;

    // Minted count per stage per token.
    mapping(uint256 => mapping(uint256 => uint256)) internal _stageMintedCountsPerToken;

    // Mint fee for each item minted
    uint256 internal _mintFee;
}
