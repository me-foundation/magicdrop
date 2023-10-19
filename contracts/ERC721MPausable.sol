//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/Pausable.sol";
import "./ERC721M.sol";

contract ERC721MPausable is ERC721M, Pausable {
    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint64 timestampExpirySeconds,
        address mintCurrency
    )
    ERC721M(
        collectionName,
        collectionSymbol,
        tokenURISuffix,
        maxMintableSupply,
        globalWalletLimit,
        cosigner,
        timestampExpirySeconds,
        mintCurrency
    )
    {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override(ERC721A, IERC721A) whenNotPaused {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public payable virtual override(ERC721A, IERC721A) whenNotPaused {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public payable virtual override(ERC721A, IERC721A) whenNotPaused {
        super.safeTransferFrom(from, to, tokenId, data);
    }
}