// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "../../common/Structs.sol";

contract ERC721MStorage {
    // Controls if new tokens can be minted
    bool internal _mintable;

    // Maximum number of tokens that can ever be minted
    uint256 internal _maxMintableSupply;

    // Maximum number of tokens a single wallet can mint across all stages
    uint256 internal _globalWalletLimit;

    // Base URI for token metadata (e.g., "ipfs://QmYx...")
    string internal _currentBaseURI;

    // File extension for token URIs (e.g., ".json")
    string internal _tokenURISuffix;

    // Array of mint stages with pricing, limits, and timing configurations
    MintStageInfo[] internal _mintStages;

    // Tracks number of tokens minted per wallet for each stage
    mapping(uint256 => mapping(address => uint32)) internal _stageMintedCountsPerWallet;

    // Tracks total number of tokens minted in each stage
    mapping(uint256 => uint256) internal _stageMintedCounts;

    // ERC20 token address for mint payments (address(0) for native currency)
    address internal _mintCurrency;

    // Accumulated fees from all mints
    uint256 internal _totalMintFee;

    // Address that receives mint payments
    address internal _fundReceiver;

    // Collection-level metadata URI for marketplaces
    string internal _contractURI;

    // Controls if tokens can be transferred between addresses
    bool internal _transferable;

    // Prevents multiple initializations of contract settings
    bool internal _setupLocked;
}
