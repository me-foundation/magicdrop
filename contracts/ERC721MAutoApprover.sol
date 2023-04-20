//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721M.sol";

contract ERC721MAutoApprover is ERC721M {
    address private _autoApproveAddress;

    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint64 timestampExpirySeconds,
        address autoApproveAddress
    )
        ERC721M(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            cosigner,
            timestampExpirySeconds
        )
    {
        _autoApproveAddress = autoApproveAddress;
    }

    function mint(
        uint32 qty,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external payable override nonReentrant {
        _mintInternal(qty, msg.sender, proof, timestamp, signature);

        // if auto approve address is not all zero, check if the address is already approved
        if (
            _autoApproveAddress != address(0) &&
            !super.isApprovedForAll(msg.sender, _autoApproveAddress)
        ) {
            if (!super.isApprovedForAll(msg.sender, _autoApproveAddress)) {
                // approve the address if not already approved
                super.setApprovalForAll(_autoApproveAddress, true);
            }
        }
    }
}
