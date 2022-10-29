// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "erc721a/contracts/ERC721A.sol";

import "./IBucketAuction.sol";
import "./ERC721M.sol";

contract BucketAuction is IBucketAuction, ERC721M {
    bool private _claimable;
    uint256 private _minimumContributionInWei;
    uint256 private _price;
    bool private _auctionActive;
    mapping(address => User) private _userData;

    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint256 minimumContributionInWei
    )
        ERC721M(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            cosigner,
            /* timestampExpirySeconds= */
            300
        )
    {
        _claimable = false;
        _minimumContributionInWei = minimumContributionInWei;
    }

    modifier isClaimable() {
        if (!_claimable) revert NotClaimable();
        _;
    }

    modifier isAuctionActive() {
        if (!_auctionActive) revert BucketAuctionNotActive();
        _;
    }

    modifier isAuctionInactive() {
        if (_auctionActive) revert BucketAuctionActive();
        _;
    }

    function getMinimumContributionInWei() external view returns (uint256) {
        return _minimumContributionInWei;
    }

    function getPrice() external view returns (uint256) {
        return _price;
    }

    function getAuctionActive() external view returns (bool) {
        return _auctionActive;
    }

    function getUserData(address user) external view returns (User memory) {
        return _userData[user];
    }

    function getClaimable() external view returns (bool) {
        return _claimable;
    }

    function setClaimable(bool b) external onlyOwner {
        _claimable = b;
        emit SetClaimable(b);
    }

    /**
     * @notice begin the auction.
     * @dev cannot be reactivated after price has been set.
     * @param b set 'true' to start auction, set 'false' to stop auction.
     */
    function setAuctionActive(bool b) external onlyOwner cannotMint {
        if (_price != 0) revert PriceHasBeenSet();
        _auctionActive = b;
    }

    /**
     * @notice place a bid in ETH or add to your existing bid. Calling this
     *   multiple times will increase your bid amount. All bids placed are final
     *   and cannot be reversed.
     */
    function bid() external payable isAuctionActive nonReentrant cannotMint {
        User storage bidder = _userData[msg.sender]; // get user's current bid total
        uint256 contribution_ = bidder.contribution; // bidder.contribution is uint216
        unchecked {
            // does not overflow
            contribution_ += msg.value;
        }
        if (contribution_ < _minimumContributionInWei)
            revert LowerThanMinBidAmount();
        bidder.contribution = uint216(contribution_);
        emit Bid(msg.sender, msg.value, contribution_, address(this).balance);
    }

    /**
     * @notice set the minimum contribution required to place a bid
     * @dev set this price in wei, not eth!
     * @param minimumContributionInWei new price, set in wei
     */
    function setMinimumContribution(uint256 minimumContributionInWei)
        external
        onlyOwner
    {
        _minimumContributionInWei = minimumContributionInWei;
        emit SetMinimumContribution(minimumContributionInWei);
    }

    /**
     * @notice set the clearing price after all bids have been placed.
     * @dev set this price in wei, not eth!
     * @param priceInWei new price, set in wei
     */
    function setPrice(uint256 priceInWei)
        external
        isAuctionInactive
        onlyOwner
        cannotMint
    {
        if (_claimable) revert CannotSetPriceIfClaimable();

        _price = priceInWei;
        emit SetPrice(priceInWei);
    }

    /**
     * @dev handles all minting.
     * @param to address to mint tokens to.
     * @param numberOfTokens number of tokens to mint.
     */
    function _internalMint(address to, uint256 numberOfTokens)
        internal
        hasSupply(numberOfTokens)
    {
        _safeMint(to, numberOfTokens);
    }

    /**
     * @dev handles multiple send tokens methods.
     * @param to address to send tokens to.
     * @param n number of tokens to send.
     */
    function _sendTokens(address to, uint256 n) internal {
        uint256 price = _price; // storage to memory
        if (price == 0) revert PriceNotSet();

        User storage user = _userData[to]; // get user data
        uint256 claimed = user.tokensClaimed; // user.tokensClaimed is uint32
        claimed += n;

        if (claimed > (user.contribution / price))
            revert CannotSendMoreThanUserPurchased();
        user.tokensClaimed = uint32(claimed);
        _internalMint(to, n);
    }

    /**
     * @notice get the number of tokens purchased by an address, after the
     *   clearing price has been set.
     * @param a address to query.
     */
    function amountPurchased(address a) public view returns (uint256) {
        if (_price == 0) revert PriceNotSet();
        return _userData[a].contribution / _price;
    }

    /**
     * @notice get the refund amount for an account, after the clearing price
     *   has been set.
     * @param a address to query.
     */
    function refundAmount(address a) public view returns (uint256) {
        if (_price == 0) revert PriceNotSet();
        return _userData[a].contribution % _price;
    }

    // functions for project owner to pay to send tokens/refund

    /**
     * @notice mint tokens to an address.
     * @dev purchased amount for an address can be sent in multiple calls.
     *   Can only be called after clearing price has been set.
     * @param to address to send tokens to.
     * @param n number of tokens to send.
     */
    function sendTokens(address to, uint256 n) public onlyOwner {
        _sendTokens(to, n);
    }

    /**
     * @notice send all of an address's purchased tokens.
     * @dev if some tokens have already been sent, the remainder must be sent
     *   using sendTokens().
     * @param to address to send tokens to.
     */
    function sendAllTokens(address to) public onlyOwner {
        _sendTokens(to, amountPurchased(to));
    }

    /**
     * @notice send refund to an address. Refunds are unsuccessful bids or
     *   an address's remaining eth after all their tokens have been paid for.
     * @dev can only be called after the clearing price has been set.
     * @param to the address to refund.
     */
    function sendRefund(address to) public onlyOwner {
        uint256 price = _price; // storage to memory
        if (price == 0) revert PriceNotSet();

        User storage user = _userData[to]; // get user data
        if (user.refundClaimed) revert UserAlreadyClaimed();
        user.refundClaimed = true;

        uint256 refundValue = user.contribution % price;
        (bool success, ) = to.call{value: refundValue}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice send refunds to a batch of addresses.
     * @param addresses array of addresses to refund.
     */
    function sendRefundBatch(address[] calldata addresses) external onlyOwner {
        for (uint256 i; i < addresses.length; i++) {
            sendRefund(addresses[i]);
        }
    }

    /**
     * @notice send tokens to a batch of addresses.
     * @param addresses array of addresses to send tokens to.
     */
    function sendTokensBatch(address[] calldata addresses) external onlyOwner {
        for (uint256 i; i < addresses.length; i++) {
            _sendTokens(addresses[i], amountPurchased(addresses[i]));
        }
    }

    /**
     * @notice send refunds and tokens to an address.
     * @dev can only be called after the clearing price has been set.
     * @param to the address to refund.
     */
    function sendTokensAndRefund(address to) public onlyOwner nonReentrant {
        _sendTokensAndRefund(to);
    }

    function claimTokensAndRefund() public isClaimable nonReentrant {
        _sendTokensAndRefund(msg.sender);
    }

    function _sendTokensAndRefund(address to) internal {
        uint256 price = _price;
        if (price == 0) revert PriceNotSet();

        User storage user = _userData[to]; // get user data
        uint256 userContribution = user.contribution;

        // send refund
        if (user.refundClaimed) revert UserAlreadyClaimed();
        user.refundClaimed = true;
        uint256 refundValue = user.contribution % price;
        (bool success, ) = to.call{value: refundValue}("");
        if (!success) revert TransferFailed();

        // send tokens
        uint256 n = userContribution / price;
        if (n > 0) {
            if (user.tokensClaimed != 0) revert AlreadySentTokensToUser();
            user.tokensClaimed = uint32(n);
            _internalMint(to, n);
        }
    }

    /**
     * @notice send refunds and tokens to a batch of addresses.
     * @param addresses array of addresses to send tokens to.
     */
    function sendTokensAndRefundBatch(address[] calldata addresses)
        external
        onlyOwner
    {
        for (uint256 i; i < addresses.length; i++) {
            sendTokensAndRefund(addresses[i]);
        }
    }
}
