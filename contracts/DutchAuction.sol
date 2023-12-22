// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "erc721a/contracts/ERC721A.sol";

import "./IDutchAuction.sol";
import "./ERC721M.sol";

contract DutchAuction is IDutchAuction, ERC721M {
    bool private immutable _refundable;
    uint256 private _settledPriceInWei;
    Config private _config;
    mapping(address => User) private _userData;

    constructor(
        // ERC721M
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        bool refundable,
        address crossmintAddress
    )
        ERC721M(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            cosigner,
            /* timestampExpirySeconds= */
            300,
            /* mintCurrency= */
            address(0),
            crossmintAddress
        )
    {
        _refundable = refundable;
    }

    modifier validTime() {
        Config memory config = _config;
        if (
            block.timestamp > config.endTime ||
            block.timestamp < config.startTime
        ) revert InvalidStartEndTime(config.startTime, config.endTime);
        _;
    }

    function setConfig(
        uint256 startAmountInWei,
        uint256 endAmountInWei,
        uint64 startTime,
        uint64 endTime
    ) external onlyOwner {
        if (startTime == 0 || startTime >= endTime)
            revert InvalidStartEndTime(startTime, endTime);
        if (startAmountInWei == 0) revert InvalidAmountInWei();

        _config = Config({
            startAmountInWei: startAmountInWei,
            endAmountInWei: endAmountInWei,
            startTime: startTime,
            endTime: endTime
        });
    }

    function getConfig() external view returns (Config memory) {
        return _config;
    }

    function getSettledPriceInWei() external view returns (uint256) {
        return _settledPriceInWei;
    }

    function getCurrentPriceInWei() public view returns (uint256) {
        Config memory config = _config; // storage to memory
        // Return startAmountInWei if auction not started
        if (block.timestamp <= config.startTime) return config.startAmountInWei;
        // Return endAmountInWei if auction ended
        if (block.timestamp >= config.endTime) return config.endAmountInWei;

        if (config.startAmountInWei != config.endAmountInWei) {
            uint256 amount;
            bool roundUp = true; // we always round up the calculation

            // Declare variables to derive in the subsequent unchecked scope.
            uint256 duration;
            uint256 elapsed;
            uint256 remaining;

            // Skip underflow checks as startTime <= block.timestamp < endTime.
            unchecked {
                // Derive the duration for the order and place it on the stack.
                duration = config.endTime - config.startTime;

                // Derive time elapsed since the order started & place on stack.
                elapsed = block.timestamp - config.startTime;

                // Derive time remaining until order expires and place on stack.
                remaining = duration - elapsed;
            }

            // Aggregate new amounts weighted by time with rounding factor.
            // TODO: check the math boundary here
            uint256 totalBeforeDivision = ((config.startAmountInWei *
                remaining) + (config.endAmountInWei * elapsed));

            // Use assembly to combine operations and skip divide-by-zero check.
            assembly {
                // Multiply by iszero(iszero(totalBeforeDivision)) to ensure
                // amount is set to zero if totalBeforeDivision is zero,
                // as intermediate overflow can occur if it is zero.
                amount := mul(
                    iszero(iszero(totalBeforeDivision)),
                    // Subtract 1 from the numerator and add 1 to the result if
                    // roundUp is true to get the proper rounding direction.
                    // Division is performed with no zero check as duration
                    // cannot be zero as long as startTime < endTime.
                    add(
                        div(sub(totalBeforeDivision, roundUp), duration),
                        roundUp
                    )
                )
            }

            // Return the current amount.
            return amount;
        }

        // Return the original amount as startAmount == endAmount.
        return config.endAmountInWei;
    }

    function bid(uint32 qty)
        external
        payable
        nonReentrant
        hasSupply(qty)
        validTime
    {
        uint256 price = getCurrentPriceInWei();
        if (msg.value < qty * price) revert NotEnoughValue();

        if (_refundable) {
            User storage bidder = _userData[msg.sender]; // get user's current bid total
            bidder.contribution = bidder.contribution + uint216(msg.value);
            bidder.tokensBidded = bidder.tokensBidded + qty;

            // _settledPriceInWei is always the minimum price of all the bids' unit price
            if (price < _settledPriceInWei || _settledPriceInWei == 0) {
                _settledPriceInWei = price;
            }
        }
        _safeMint(msg.sender, qty);
        emit Bid(msg.sender, qty, price);
    }

    function claimRefund() external nonReentrant {
        Config memory config = _config;
        if (!_refundable) revert NotRefundable();
        if (config.endTime > block.timestamp) revert NotEnded();

        User storage user = _userData[msg.sender];
        if (user.refundClaimed) revert UserAlreadyClaimed();
        user.refundClaimed = true;
        uint256 refundInWei = user.contribution -
            (_settledPriceInWei * user.tokensBidded);
        if (refundInWei > 0) {
            (bool success, ) = msg.sender.call{value: refundInWei}("");
            if (!success) revert TransferFailed();
            emit ClaimRefund(msg.sender, refundInWei);
        }
    }
}
