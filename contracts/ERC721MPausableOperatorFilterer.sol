//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721MPausable.sol";
import "./OperatorFilter/DefaultOperatorFilterer.sol";

contract ERC721MPausableOperatorFilterer is
    ERC721MPausable,
    DefaultOperatorFilterer
{
    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint64 timestampExpirySeconds,
        address mintCurrency,
        address crossMintAddress
    )
        ERC721MPausable(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            cosigner,
            timestampExpirySeconds,
            mintCurrency,
            crossMintAddress
        )
    {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721MPausable) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721MPausable) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable override(ERC721MPausable) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
