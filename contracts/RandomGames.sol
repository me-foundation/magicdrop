//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ERC721CM, ERC721ACQueryable, IERC721A} from "./ERC721CM.sol";

/**
 * @title RandomGamesMinting
 */
contract RandomGamesMinting is ERC721CM {
    address immutable _proxyContract;

    constructor(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        address cosigner,
        uint64 timestampExpirySeconds,
        address mintCurrency,
        address fundReceiver,
        address proxyContract
    )
        ERC721CM(
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
    {
        _proxyContract = proxyContract;
    }

    function setProxyContract(address newProxyContract) external onlyOwner {
        _proxyContract = newProxyContract;
    }

    function mint(
        uint32 qty,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external override payable virtual nonReentrant {
        _mintInternal(qty, msg.sender, 0, proof, timestamp, signature);

        address[] memory minters = new address[](qty);
        for (uint256 i = 0; i < qty; i++) {
            minters[i] = msg.sender;
        }
        (bool success, ) = _proxyContract.call(abi.encodeWithSignature("mint(address[])", minters));

        require(success, "Proxy call failed");
    }

    function mintWithLimit(
        uint32 qty,
        uint32 limit,
        bytes32[] calldata proof,
        uint64 timestamp,
        bytes calldata signature
    ) external override payable virtual nonReentrant {
        _mintInternal(qty, msg.sender, limit, proof, timestamp, signature);

        address[] memory minters = new address[](qty);
        for (uint256 i = 0; i < qty; i++) {
            minters[i] = msg.sender;
        }
        (bool success, ) = _proxyContract.call(abi.encodeWithSignature("mint(address[])", minters));

        require(success, "Proxy call failed");
    }
}
