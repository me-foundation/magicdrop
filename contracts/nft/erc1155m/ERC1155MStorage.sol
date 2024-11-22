// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {MintStageInfo1155} from "../../common/Structs.sol";

contract ERC1155MStorage {
    // Mint stage information. See MintStageInfo for details.
    MintStageInfo1155[] internal _mintStages;

    string public name;
    string public symbol;
    bool internal _transferable; // Whether the token can be transferred.
    uint256[] internal _maxMintableSupply; // The total mintable supply per token.
    uint256[] internal _globalWalletLimit; // Global wallet limit, across all stages, per token.
    uint256 internal _totalMintFee;
    address internal _mintCurrency; // If 0 address, use native currency.
    uint256 internal _numTokens;
    address internal _fundReceiver;

    mapping(uint256 => mapping(uint256 => mapping(address => uint32))) internal _stageMintedCountsPerTokenPerWallet;
    mapping(uint256 => mapping(uint256 => uint256)) internal _stageMintedCountsPerToken;
}
