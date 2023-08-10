//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import { IONFT721Core, ONFT721CoreLite } from "./onft/ONFT721CoreLite.sol";
import { ERC721MLite, ERC721A, ERC721A__IERC721Receiver, IERC721A } from "./ERC721MLite.sol";
import { IONFT721 } from "@layerzerolabs/solidity-examples/contracts/token/onft/IONFT721.sol";

/**
 * @title ERC721MOnft
 *
 * @dev ERC721MOnft is an ERC721M contract with LayerZero integration. 
 */
contract ERC721MOnft is ERC721MLite, ONFT721CoreLite, ERC721A__IERC721Receiver {
    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint64 timestampExpirySeconds,
        uint256 minGasToTransferAndStore,
        address lzEndpoint
    ) ERC721MLite(collectionName, collectionSymbol, tokenURISuffix, maxMintableSupply, globalWalletLimit, cosigner, timestampExpirySeconds) 
    ONFT721CoreLite(minGasToTransferAndStore, lzEndpoint) {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ONFT721CoreLite, ERC721A, IERC721A) returns (bool) {
        return interfaceId == type(IONFT721Core).interfaceId || super.supportsInterface(interfaceId);
    }

    function _debitFrom(address _from, uint16, bytes memory, uint _tokenId) internal virtual  override {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "caller not owner/approved");
        require(ERC721A.ownerOf(_tokenId) == _from, "from address not owner");
        safeTransferFrom(_from, address(this), _tokenId);
    }

    function _creditTo(uint16, address _toAddress, uint _tokenId) internal virtual override {
        require(_exists(_tokenId) && ERC721A.ownerOf(_tokenId) == address(this), "not exist/not owned by contract");
        safeTransferFrom(address(this), _toAddress, _tokenId);
    }

    function onERC721Received(address, address, uint, bytes memory) public virtual override returns (bytes4) {
        return ERC721A__IERC721Receiver.onERC721Received.selector;
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }
}
