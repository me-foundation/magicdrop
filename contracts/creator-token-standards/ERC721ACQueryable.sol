// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./CreatorTokenBase.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

/**
 * @title ERC721ACQueryable
 */
abstract contract ERC721ACQueryable is ERC721AQueryable, CreatorTokenBase {
    constructor(
        string memory name_,
        string memory symbol_
    ) CreatorTokenBase() ERC721A(name_, symbol_) {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721A, IERC721A) returns (bool) {
        return
            interfaceId == type(ICreatorToken).interfaceId ||
            ERC721A.supportsInterface(interfaceId);
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
