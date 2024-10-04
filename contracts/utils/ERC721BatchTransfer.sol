//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title ERC721 Batch Transfer
 *
 * @notice Transfer ERC721 tokens in batches to a single wallet or multiple wallets. This supports ERC721M and ERC721CM contracts.
 * @notice To use any of the methods in this contract the user has to approve this contract to control their tokens using either `setApproveForAll` or `approve` functions from the ERC721 contract.
 */
contract ERC721BatchTransfer {
    error InvalidArguments();
    error NotOwnerOfToken();

    event BatchTransferToSingle(address indexed contractAddress, address indexed to, uint256 amount);

    event BatchTransferToMultiple(address indexed contractAddress, uint256 amount);

    /**
     * @notice Transfer multiple tokens to the same wallet using the ERC721.transferFrom method.
     * @notice If you don't know what that means, use the `safeBatchTransferToSingleWallet` method instead
     * @param erc721Contract the address of the nft contract
     * @param to the address that will receive the nfts
     * @param tokenIds the list of tokens that will be transferred
     */
    function batchTransferToSingleWallet(IERC721 erc721Contract, address to, uint256[] calldata tokenIds) external {
        uint256 length = tokenIds.length;
        for (uint256 i; i < length;) {
            uint256 tokenId = tokenIds[i];
            address owner = erc721Contract.ownerOf(tokenId);
            if (msg.sender != owner) {
                revert NotOwnerOfToken();
            }
            erc721Contract.transferFrom(owner, to, tokenId);
            unchecked {
                ++i;
            }
        }
        emit BatchTransferToSingle(address(erc721Contract), to, length);
    }

    /**
     * @notice transfer multiple tokens to the same wallet using the `ERC721.safeTransferFrom` method
     * @param erc721Contract the address of the nft contract
     * @param to the address that will receive the nfts
     * @param tokenIds the list of tokens that will be transferred
     */
    function safeBatchTransferToSingleWallet(IERC721 erc721Contract, address to, uint256[] calldata tokenIds)
        external
    {
        uint256 length = tokenIds.length;
        for (uint256 i; i < length;) {
            uint256 tokenId = tokenIds[i];
            address owner = erc721Contract.ownerOf(tokenId);
            if (msg.sender != owner) {
                revert NotOwnerOfToken();
            }
            erc721Contract.safeTransferFrom(owner, to, tokenId);
            unchecked {
                ++i;
            }
        }
        emit BatchTransferToSingle(address(erc721Contract), to, length);
    }

    /**
     * @notice Transfer multiple tokens to multiple wallets using the ERC721.transferFrom method
     * @notice If you don't know what that means, use the `safeBatchTransferToMultipleWallets` method instead
     * @notice The tokens in `tokenIds` will be transferred to the addresses in the same position in `tos`
     * @notice E.g.: if tos = [0x..1, 0x..2, 0x..3] and tokenIds = [1, 2, 3], then:
     *         0x..1 will receive token 1;
     *         0x..2 will receive token 2;
     *         0x..3 will receive token 3;
     * @param erc721Contract the address of the nft contract
     * @param tos the list of addresses that will receive the nfts
     * @param tokenIds the list of tokens that will be transferred
     */
    function batchTransferToMultipleWallets(IERC721 erc721Contract, address[] calldata tos, uint256[] calldata tokenIds)
        external
    {
        uint256 length = tokenIds.length;
        if (tos.length != length) revert InvalidArguments();

        for (uint256 i; i < length;) {
            uint256 tokenId = tokenIds[i];
            address owner = erc721Contract.ownerOf(tokenId);
            address to = tos[i];
            if (msg.sender != owner) {
                revert NotOwnerOfToken();
            }
            erc721Contract.transferFrom(owner, to, tokenId);
            unchecked {
                ++i;
            }
        }

        emit BatchTransferToMultiple(address(erc721Contract), length);
    }

    /**
     * @notice Transfer multiple tokens to multiple wallets using the ERC721.safeTransferFrom method
     * @notice The tokens in `tokenIds` will be transferred to the addresses in the same position in `tos`
     * @notice E.g.: if tos = [0x..1, 0x..2, 0x..3] and tokenIds = [1, 2, 3], then:
     *         0x..1 will receive token 1;
     *         0x..2 will receive token 2;
     *         0x..3 will receive token 3;
     * @param erc721Contract the address of the nft contract
     * @param tos the list of addresses that will receive the nfts
     * @param tokenIds the list of tokens that will be transferred
     */
    function safeBatchTransferToMultipleWallets(
        IERC721 erc721Contract,
        address[] calldata tos,
        uint256[] calldata tokenIds
    ) external {
        uint256 length = tokenIds.length;
        if (tos.length != length) revert InvalidArguments();

        for (uint256 i; i < length;) {
            uint256 tokenId = tokenIds[i];
            address owner = erc721Contract.ownerOf(tokenId);
            address to = tos[i];
            if (msg.sender != owner) {
                revert NotOwnerOfToken();
            }
            erc721Contract.safeTransferFrom(owner, to, tokenId);
            unchecked {
                ++i;
            }
        }

        emit BatchTransferToMultiple(address(erc721Contract), length);
    }
}
