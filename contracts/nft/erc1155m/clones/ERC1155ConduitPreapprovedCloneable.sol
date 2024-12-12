// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC1155} from "solady/src/tokens/ERC1155.sol";

/// @title  ERC1155ConduitPreapprovedCloneable
/// @notice ERC1155 with the MagicEden conduit preapproved.
abstract contract ERC1155ConduitPreapprovedCloneable is ERC1155 {
    /// @dev The canonical MagicEden conduit.
    address internal constant _CONDUIT = 0x2052f8A2Ff46283B30084e5d84c89A2fdBE7f74b;

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data)
        public
        virtual
        override
    {
        _safeTransfer(_by(), from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) public virtual override {
        _safeBatchTransfer(_by(), from, to, ids, amounts, data);
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        if (operator == _CONDUIT) return true;
        return ERC1155.isApprovedForAll(owner, operator);
    }

    function _by() internal view virtual returns (address result) {
        assembly {
            // `msg.sender == _CONDUIT ? address(0) : msg.sender`.
            result := mul(iszero(eq(caller(), _CONDUIT)), caller())
        }
    }
}
