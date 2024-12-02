//SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {ERC721A, ERC721M, IERC721A, Ownable} from "../ERC721M.sol";
import {UpdatableOperatorFilterer} from "operator-filter-registry/src/UpdatableOperatorFilterer.sol";
import {CANONICAL_OPERATOR_FILTER_REGISTRY_ADDRESS, ME_SUBSCRIPTION} from "../../../utils/Constants.sol";

contract ERC721MOperatorFilterer is ERC721M, UpdatableOperatorFilterer {
    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint256 timestampExpirySeconds,
        address mintCurrency,
        address fundReceiver
    )
        UpdatableOperatorFilterer(CANONICAL_OPERATOR_FILTER_REGISTRY_ADDRESS, ME_SUBSCRIPTION, true)
        ERC721M(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            cosigner,
            timestampExpirySeconds,
            mintCurrency,
            fundReceiver
        )
    {}

    function owner() public view override(Ownable, UpdatableOperatorFilterer) returns (address) {
        return Ownable.owner();
    }

    function transferFrom(address from, address to, uint256 tokenId)
        public
        payable
        override(ERC721A, IERC721A)
        onlyAllowedOperator(from)
    {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId)
        public
        payable
        override(ERC721A, IERC721A)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        payable
        override(ERC721A, IERC721A)
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
