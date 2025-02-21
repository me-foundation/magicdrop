// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC1155} from "solady/src/tokens/ext/zksync/ERC1155.sol";

/// @title ERC1155ConduitPreapprovedCloneable
/// @notice ERC1155 token with the MagicEden conduit preapproved for seamless transactions.
abstract contract ERC1155ConduitPreapprovedCloneable is ERC1155 {
    /// @dev The canonical MagicEden conduit address.
    address internal constant _CONDUIT = 0x2052f8A2Ff46283B30084e5d84c89A2fdBE7f74b;

    /// @notice Safely transfers `amount` tokens of type `id` from `from` to `to`.
    /// @param from The address holding the tokens.
    /// @param to The address to transfer the tokens to.
    /// @param id The token type identifier.
    /// @param amount The number of tokens to transfer.
    /// @param data Additional data with no specified format.
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        virtual
        override
    {
        _safeTransfer(_by(), from, to, id, amount, data);
    }

    /// @notice Safely transfers a batch of tokens from `from` to `to`.
    /// @param from The address holding the tokens.
    /// @param to The address to transfer the tokens to.
    /// @param ids An array of token type identifiers.
    /// @param amounts An array of amounts to transfer for each token type.
    /// @param data Additional data with no specified format.
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual override {
        _safeBatchTransfer(_by(), from, to, ids, amounts, data);
    }

    /// @notice Checks if `operator` is approved to manage all of `owner`'s tokens.
    /// @param owner The address owning the tokens.
    /// @param operator The address to query for approval.
    /// @return True if `operator` is approved, otherwise false.
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        if (operator == _CONDUIT) return true;
        return ERC1155.isApprovedForAll(owner, operator);
    }

    /// @dev Determines the address initiating the transfer.
    /// If the caller is the predefined conduit, returns address(0), else returns the caller's address.
    /// @return result The address initiating the transfer.
    function _by() internal view virtual returns (address result) {
        assembly {
            // `msg.sender == _CONDUIT ? address(0) : msg.sender`.
            result := mul(iszero(eq(caller(), _CONDUIT)), caller())
        }
    }
}
