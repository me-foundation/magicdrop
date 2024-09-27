// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {OwnableInitializable} from "@limitbreak/creator-token-standards/src/access/OwnableInitializable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title UpdatableRoyaltiesInitializable
 * @dev This contract is not meant for use in Upgradeable Proxy contracts though it may base on Upgradeable contract. The purpose of this
 * contract is for use with EIP-1167 Minimal Proxies (Clones).
 */
abstract contract UpdatableRoyaltiesInitializable is
    ERC2981,
    OwnableInitializable
{
    event DefaultRoyaltySet(address indexed receiver, uint96 feeNumerator);
    event TokenRoyaltySet(
        uint256 indexed tokenId,
        address indexed receiver,
        uint96 feeNumerator
    );

    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) public onlyOwner {
        super._setDefaultRoyalty(receiver, feeNumerator);
        emit DefaultRoyaltySet(receiver, feeNumerator);
    }

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) public onlyOwner {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit TokenRoyaltySet(tokenId, receiver, feeNumerator);
    }
}
