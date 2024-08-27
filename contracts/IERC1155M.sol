//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


interface IERC1155M {
    error CannotIncreaseMaxMintableSupply();
    error NewSupplyLessThanTotalSupply();
    error GlobalWalletLimitOverflow();
    error InsufficientStageTimeGap();
    error InvalidLimitArgsLength();
    error InvalidProof();
    error InvalidStage();
    error InvalidStageArgsLength();
    error InvalidTokenId();
    error InvalidStartAndEndTimestamp();
    error NoSupplyLeft();
    error NotAuthorized();
    error NotEnoughValue();
    error NotTransferable();
    error StageSupplyExceeded();
    error TimestampExpired();
    error TransferFailed();
    error WalletGlobalLimitExceeded();
    error WalletStageLimitExceeded();
    error WithdrawFailed();
    error WrongMintCurrency();
    error NotSupported();

    struct MintStageInfo {
        uint80[] price;
        uint80[] mintFee;
        uint32[] walletLimit; // 0 for unlimited
        bytes32[] merkleRoot; // 0x0 for no presale enforced
        uint24[] maxStageSupply; // 0 for unlimited
        uint64 startTimeUnixSeconds;
        uint64 endTimeUnixSeconds;
    }

    event UpdateStage(
        uint256 indexed stage,
        uint80[] price,
        uint80[] mintFee,
        uint32[] walletLimit,
        bytes32[] merkleRoot,
        uint24[] maxStageSupply,
        uint64 startTimeUnixSeconds,
        uint64 endTimeUnixSeconds
    );
    event SetMaxMintableSupply(uint256 indexed tokenId, uint256 maxMintableSupply);
    event SetGlobalWalletLimit(uint256 indexed tokenId, uint256 globalWalletLimit);
    event Withdraw(uint256 value);
    event WithdrawERC20(address indexed mintCurrency, uint256 value);
    event SetTransferable(bool transferable);
    event DefaultRoyaltySet(address receiver, uint96 feeNumerator);
    event TokenRoyaltySet(uint256 indexed tokenId, address receiver, uint96 feeNumerator);

    function getNumberStages() external view returns (uint256);

    function getGlobalWalletLimit(uint256 tokenId) external view returns (uint256);

    function getMaxMintableSupply(uint256 tokenId) external view returns (uint256);

    function totalMintedByAddress(address account) external view returns (uint256[] memory);

    function getStageInfo(uint256 stage) external view returns (MintStageInfo memory, uint256[] memory, uint256[] memory);

    function mint(
        uint256 tokenId,
        uint32 qty,
        bytes32[] calldata proof
    ) external payable;

    function mintWithLimit(
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof
    ) external payable;

    function authorizedMint(
        address to,
        uint256 tokenId,
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof
    ) external payable;
}
