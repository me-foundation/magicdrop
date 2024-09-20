//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ERC2981, UpdatableRoyaltiesInitializable} from "../../../royalties/UpdatableRoyaltiesInitializable.sol";
import {ERC721ACQueryableInitializable, ERC721CMInitializable, IERC721AUpgradeable, OwnableInitializable} from "../ERC721CMInitializable.sol";

/**
 * @title ERC721CMRoyaltiesInitializable
 * @dev This contract is not meant for use in Upgradeable Proxy contracts though it may base on Upgradeable contract. The purpose of this
 * contract is for use with EIP-1167 Minimal Proxies (Clones).
 */
contract ERC721CMRoyaltiesInitializable is
    ERC721CMInitializable,
    UpdatableRoyaltiesInitializable
{
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory collectionName,
        string memory collectionSymbol,
        string memory tokenURISuffix,
        uint256 maxMintableSupply,
        uint256 globalWalletLimit,
        uint64 timestampExpirySeconds,
        address mintCurrency,
        address fundReceiver,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) public initializerERC721A initializer {
        __ERC721CMInitializable_init(
            collectionName,
            collectionSymbol,
            tokenURISuffix,
            maxMintableSupply,
            globalWalletLimit,
            timestampExpirySeconds,
            mintCurrency,
            fundReceiver
        );
        setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC2981, ERC721ACQueryableInitializable, IERC721AUpgradeable)
        returns (bool)
    {
        return
            ERC721ACQueryableInitializable.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    function _requireCallerIsContractOwner()
        internal
        view
        virtual
        override(ERC721CMInitializable, OwnableInitializable)
    {
        _checkOwner();
    }
}
