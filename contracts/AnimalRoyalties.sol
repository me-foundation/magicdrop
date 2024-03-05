//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ERC2981, UpdatableRoyalties} from "./royalties/UpdatableRoyalties.sol";
import {Animal, ERC721ACQueryable, IERC721A} from "./Animal.sol";

/**
 * @title AnimalRoyalties
 */
contract AnimalRoyalties is Animal, UpdatableRoyalties {
    constructor(
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
    )
        Animal(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            cosigner,
            timestampExpirySeconds,
            mintCurrency
        )
        UpdatableRoyalties(royaltyReceiver, royaltyFeeNumerator)
    {}

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721ACQueryable, IERC721A)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
