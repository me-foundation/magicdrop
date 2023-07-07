//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { IONFT721Core, ONFT721Core } from "@layerzerolabs/solidity-examples/contracts/token/onft/ONFT721Core.sol";
import { ERC721MCore, ERC721A, ERC721A__IERC721Receiver, IERC721A } from "./ERC721MCore.sol";

/**
 * @title ERC721MOnft
 *
 * @dev ERC721A subclass with MagicEden launchpad features including
 *  - ONFT support
 *  - multiple minting stages with time-based auto stage switch
 *  - global and stage wallet-level minting limit
 *  - whitelist using merkle tree
 *  - anti-botting
 */
contract ERC721MOnft is ERC721MCore, ONFT721Core, ERC721A__IERC721Receiver {

    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        address cosigner,
        uint64 timestampExpirySeconds,
        uint256 minGasToTransferAndStore,
        address lzEndpoint
    ) ERC721MCore(collectionName, collectionSymbol, tokenURISuffix, maxMintableSupply, cosigner, timestampExpirySeconds) 
    ONFT721Core(minGasToTransferAndStore, lzEndpoint) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ONFT721Core, ERC721A, IERC721A) returns (bool) {
        return interfaceId == type(IONFT721Core).interfaceId || super.supportsInterface(interfaceId);
    }

    function _debitFrom(address _from, uint16, bytes memory, uint _tokenId) override(ONFT721Core) internal virtual {
        safeTransferFrom(_from, address(this), _tokenId);
    }

    function _creditTo(uint16, address _toAddress, uint _tokenId) override(ONFT721Core) internal virtual {
        require(_exists(_tokenId) && ERC721A.ownerOf(_tokenId) == address(this));
        safeTransferFrom(address(this), _toAddress, _tokenId);
    }

    function onERC721Received(address, address, uint, bytes memory) public virtual override returns (bytes4) {
        return ERC721A__IERC721Receiver.onERC721Received.selector;
    }
}
