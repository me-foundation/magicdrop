// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721M.sol";
import "./OperatorFilter/DefaultOperatorFilterer.sol";
import "./OverworldExtensions/programmable-royalties/MinterCreatorSharedRoyalties.sol";

contract ERC721MOperatorFiltererRoyaltySplitterBasic is ERC721M, DefaultOperatorFilterer, MinterCreatorSharedRoyalties {
    struct CollectionDetails {
        string collectionName;
        string collectionSymbol;
        string tokenURISuffix;
        uint256 maxMintableSupply;
        uint256 globalWalletLimit;
        address cosigner;
        uint64 timestampExpirySeconds;
        uint256 royaltyFeeNumerator;
        uint256 minterShares;
        uint256 creatorShares;
        address creator;
        address paymentSplitterReference;
    }

    constructor(CollectionDetails memory details)
        ERC721M(
            details.collectionName,
            details.collectionSymbol,
            details.tokenURISuffix,
            details.maxMintableSupply,
            details.globalWalletLimit,
            details.cosigner,
            details.timestampExpirySeconds
        )
        MinterCreatorSharedRoyalties(
            details.royaltyFeeNumerator,
            details.minterShares,
            details.creatorShares,
            details.creator,
            details.paymentSplitterReference
        )
    {}

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721A, IERC721A) onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable override(ERC721A, IERC721A) onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }

    function _mint(address to, uint256 tokenId) internal virtual override {
        _onMinted(to, tokenId);
        super._mint(to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        _onBurned(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, IERC721A, MinterCreatorSharedRoyaltiesBase) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
