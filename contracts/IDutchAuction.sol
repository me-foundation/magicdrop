//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IDutchAuction {
    error InvalidStartEndTime();
    error NotStarted();
    error NotEnded();
    error InvalidAmountInWei();
    error NotRefundable();
    error TransferFailed();
    error UserAlreadyClaimed();

    struct User {
        uint216 contribution; // cumulative sum of Wei bids
        uint32 tokensBidded; // cumulative sum of bidded tokens
        bool refundClaimed; // has user been refunded yet
    }

    struct Config {
        uint256 startAmountInWei;
        uint256 endAmountInWei;
        uint256 startTime;
        uint256 endTime;
        bool roundUp;
    }
    event ClaimRefund(address user, uint256 refundInWei);
    event Bid(address user, uint32 qty, uint256 price);
}
