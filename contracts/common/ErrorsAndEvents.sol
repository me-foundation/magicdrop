// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ErrorsAndEvents {
    error CannotIncreaseMaxMintableSupply();
    error CrossmintAddressNotSet();
    error CrossmintOnly();
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

    event SetCrossmintAddress(address crossmintAddress);
    event SetMintable(bool mintable);
    event SetActiveStage(uint256 activeStage);
    event SetBaseURI(string baseURI);
    event SetMintCurrency(address mintCurrency);
    event Withdraw(uint256 value);
    event WithdrawERC20(address mintCurrency, uint256 value);
    event SetTimestampExpirySeconds(uint64 expiry);
}
