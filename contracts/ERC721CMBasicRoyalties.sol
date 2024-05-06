//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@limitbreak/creator-token-standards/src/programmable-royalties/BasicRoyalties.sol";
import "./ERC721CM.sol";

/**
 * @title ERC721CM with BasicRoyalties
 */
contract ERC721CMBasicRoyalties is ERC721CM, BasicRoyalties {
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
        BasicRoyalties(royaltyReceiver, royaltyFeeNumerator)
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
