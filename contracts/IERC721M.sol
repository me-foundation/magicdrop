//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/extensions/IERC721AQueryable.sol";
import "./IERC721MCore.sol";

interface IERC721M is IERC721AQueryable, IERC721MCore {
    error CannotUpdatePermanentBaseURI();
    error CrossmintAddressNotSet();
    error CrossmintOnly();
    error GlobalWalletLimitOverflow();

    event SetTimestampExpirySeconds(uint64 expiry);

    function getCosigner() external view returns (address);

    function getCrossmintAddress() external view returns (address);

    function getTimestampExpirySeconds() external view returns (uint64);

    function getTokenURISuffix() external view returns (string memory);

    function getActiveStageFromTimestamp(uint64 timestamp)
        external
        view
        returns (uint256);
}
