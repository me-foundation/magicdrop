// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/creator-token-standards/utils/AutomaticValidatorTransferApproval.sol";
import "contracts/creator-token-standards/utils/CreatorTokenBaseV2.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

/**
 * @title ERC721AC
 * @author Limit Break, Inc.
 * @notice Extends Azuki's ERC721-A implementation with Creator Token functionality, which
 *         allows the contract owner to update the transfer validation logic by managing a security policy in
 *         an external transfer validation security policy registry.  See {CreatorTokenTransferValidator}.
 */
abstract contract ERC721AC is ERC721AQueryable, CreatorTokenBaseV2, AutomaticValidatorTransferApproval {

    constructor(string memory name_, string memory symbol_) CreatorTokenBaseV2() ERC721A(name_, symbol_) {}

    /**
     * @notice Overrides behavior of isApprovedFor all such that if an operator is not explicitly approved
     *         for all, the contract owner can optionally auto-approve the 721-C transfer validator for transfers.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override(ERC721A, IERC721A) returns (bool isApproved) {
        isApproved = super.isApprovedForAll(owner, operator);

        if (!isApproved) {
            if (autoApproveTransfersFromValidator) {
                isApproved = operator == address(getTransferValidator());
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, IERC721A) returns (bool) {
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
        for (uint256 i = 0; i < quantity;) {
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
        for (uint256 i = 0; i < quantity;) {
            _validateAfterTransfer(from, to, startTokenId + i);
            unchecked {
                ++i;
            }
        }
    }

    function _msgSenderERC721A() internal view virtual override returns (address) {
        return _msgSender();
    }
}
