//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ERC721CMRoyaltiesInitializable} from "../ERC721CMRoyaltiesInitializable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title ERC721CMRoyaltiesCloneFactory
 * @dev The factory contract that creates EIP-1167 Minimal Proxies (Clones) of ERC721CMRoyaltiesInitializable.
 */
contract ERC721CMRoyaltiesCloneFactory {
    event CreateClone(address clone);

    address private immutable IMPLEMENTATION;

    constructor() {
        IMPLEMENTATION = address(new ERC721CMRoyaltiesInitializable());
    }

    function create(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint64 timestampExpirySeconds,
        address mintCurrency,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns (address) {
        address clone = Clones.clone(IMPLEMENTATION);
        ERC721CMRoyaltiesInitializable(clone).initialize(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            cosigner,
            timestampExpirySeconds,
            mintCurrency,
            royaltyReceiver,
            royaltyFeeNumerator
        );

        // Transfer the ownership to msg sender
        ERC721CMRoyaltiesInitializable(clone).transferOwnership(msg.sender);

        emit CreateClone(clone);
        return clone;
    }
}
