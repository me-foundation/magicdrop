// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../common/Structs.sol";

contract ERC721MStorage {
    // Whether this contract is mintable.
    bool internal _mintable;

    // Whether base URI is permanent. Once set, base URI is immutable.
    bool internal _baseURIPermanent;

    // The total mintable supply.
    uint256 internal _maxMintableSupply;

    // Global wallet limit, across all stages.
    uint256 internal _globalWalletLimit;

    // Current base URI.
    string internal _currentBaseURI;

    // The suffix for the token URL, e.g. ".json".
    string internal _tokenURISuffix;

    // Mint stage infomation. See MintStageInfo for details.
    MintStageInfo[] internal _mintStages;

    // Minted count per stage per wallet.
    mapping(uint256 => mapping(address => uint32)) internal _stageMintedCountsPerWallet;

    // Minted count per stage.
    mapping(uint256 => uint256) internal _stageMintedCounts;

    // Address of ERC-20 token used to pay for minting. If 0 address, use native currency.
    address internal _mintCurrency;

    // Total mint fee
    uint256 internal _totalMintFee;

    // Fund receiver
    address internal _fundReceiver;

    // The uri for the storefront-level metadata for better indexing. e.g. "ipfs://UyNGgv3jx2HHfBjQX9RnKtxj2xv2xQDtbVXoRi5rJ31234"
    string internal _contractURI;
}
