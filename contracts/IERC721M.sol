//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IERC721M {
    error GlobalWalletLimitOverflow();
    error NotMintable();
    error NoSupplyLeft();
    error InvalidStage();
    error InvalidProof();
    error WalletStageLimitExceeded();
    error WalletGlobalLimitExceeded();
    error StageSupplyExceeded();
    error NotEnoughValue();
    error InvalidStageArgsLength();
    error WithdrawFailed();
    error CannotIncreaseMaxMintableSupply();
    error FrozenBaseURI();

    struct MintStageInfo {
        uint256 price;
        uint32 walletLimit; // 0 for unlimited
        bytes32 merkleRoot; // 0x0 for no presale enforced
        uint256 maxStageSupply; // 0 for unlimited
    }

    event UpdateStage(
        uint256 stage,
        uint256 price,
        uint32 walletLimit,
        bytes32 merkleRoot,
        uint256 maxStageSupply
    );

    event SetMintable(bool mintable);
    event SetMaxMintableSupply(uint256 maxMintableSupply);
    event SetGlobalWalletLimit(uint256 globalWalletLimit);
    event SetActiveStage(uint256 activeStage);
    event SetBaseURI(string baseURI);
    event PermanentBaseURI(string baseURI);
}
