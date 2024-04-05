// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./CreatorTokenBase.sol";
import "erc721a-upgradeable/contracts/extensions/ERC721AQueryableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ERC721ACQueryable
 * @dev This contract is not meant for use in Upgradeable Proxy contracts though it may base on Upgradeable contract. The purpose of this
 * contract is for use with EIP-1167 Minimal Proxies (Clones).
 */
abstract contract ERC721ACQueryableInitializable is
    ERC721AQueryableUpgradeable,
    CreatorTokenBase,
    Initializable
{
    function __ERC721ACQueryableInitializable_init(
        string memory name_,
        string memory symbol_
    ) public initializerERC721A initializer {
        __ERC721A_init_unchained(name_, symbol_);
        __ERC721AQueryable_init_unchained();
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC721AUpgradeable, IERC721AUpgradeable)
        returns (bool)
    {
        return
            interfaceId == type(ICreatorToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// @dev Ties the erc721a _beforeTokenTransfers hook to more granular transfer validation logic
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        for (uint256 i = 0; i < quantity; ) {
            _validateBeforeTransfer(from, to, startTokenId + i);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Ties the erc721a _afterTokenTransfer hook to more granular transfer validation logic
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override {
        for (uint256 i = 0; i < quantity; ) {
            _validateAfterTransfer(from, to, startTokenId + i);
            unchecked {
                ++i;
            }
        }
    }

    function _msgSenderERC721A()
        internal
        view
        virtual
        override
        returns (address)
    {
        return _msgSender();
    }
}
