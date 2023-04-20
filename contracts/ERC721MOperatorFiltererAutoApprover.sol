//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./ERC721MOperatorFilterer.sol";

contract ERC721MOperatorFiltererAutoApprover is ERC721MOperatorFilterer {
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
        ERC721MOperatorFilterer(
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

        // auto approve address
        if (_autoApproveAddress != address(0)) {
            // check if the address is already approved
            if (!super.isApprovedForAll(msg.sender, _autoApproveAddress)) {
                // approve the address
                super.setApprovalForAll(_autoApproveAddress, true);
            }
        }
    }
}
