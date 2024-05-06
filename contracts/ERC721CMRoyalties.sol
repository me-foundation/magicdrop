//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ERC2981, UpdatableRoyalties} from "./royalties/UpdatableRoyalties.sol";
import {ERC721CM, ERC721ACQueryable, IERC721A} from "./ERC721CM.sol";

/**
 * @title ERC721CMRoyalties
 */
contract ERC721CMRoyalties is ERC721CM, UpdatableRoyalties {
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
        ERC721CM(
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

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC2981, ERC721ACQueryable, IERC721A)
        returns (bool)
    {
        return
            ERC721ACQueryable.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }
}
