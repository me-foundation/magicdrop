// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ErrorsAndEvents {
    error CannotIncreaseMaxMintableSupply();
    error GlobalWalletLimitOverflow();
    error InsufficientStageTimeGap();
    error InsufficientBalance();
    error InvalidProof();
    error InvalidStage();
    error InvalidStageArgsLength();
    error InvalidStartAndEndTimestamp();
    error NoSupplyLeft();
    error NotEnoughValue();
    error NotMintable();
    error Mintable();
    error StageSupplyExceeded();
    error TransferFailed();
    error WalletGlobalLimitExceeded();
    error WalletStageLimitExceeded();
    error WithdrawFailed();
    error WrongMintCurrency();
    error NotSupported();
    error NewSupplyLessThanTotalSupply();
    error NotTransferable();

    event SetMintable(bool mintable);
    event SetActiveStage(uint256 activeStage);
    event SetBaseURI(string baseURI);
    event SetTokenURISuffix(string suffix);
    event SetMintCurrency(address mintCurrency);
    event Withdraw(uint256 value);
    event WithdrawERC20(address mintCurrency, uint256 value);
    event DefaultRoyaltySet(address indexed receiver, uint96 feeNumerator);
    event TokenRoyaltySet(uint256 indexed tokenId, address indexed receiver, uint96 feeNumerator);
}
