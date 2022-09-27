//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IBucketAuction {
    error BucketAuctionNotActive();
    error BucketAuctionActive();
    error PriceHasBeenSet();
    error LowerThanMinBidAmount();
    error UserAlreadyClaimed();
    error TransferFailed();
    error AlreadySentTokensToUser();
    error PriceNotSet();
    error CannotSendMoreThanUserPurchased();

    struct User {
        uint216 contribution; // cumulative sum of ETH bids
        uint32 tokensClaimed; // tracker for claimed tokens
        bool refundClaimed; // has user been refunded yet
    }

    event Bid(
        address indexed bidder,
        uint256 bidAmount,
        uint256 bidderTotal,
        uint256 bucketTotal
    );
    event SetMinimumContribution(uint256 minimumContributionInWei);
    event SetPrice(uint256 price);
}
