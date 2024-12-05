// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC721AQueryableCloneable} from "./ERC721AQueryableCloneable.sol";
import {ERC721A} from "erc721a/contracts/ERC721A.sol";
import {IERC721A} from "erc721a/contracts/IERC721A.sol";

/**
 * @title  ERC721AConduitPreapprovedCloneable
 * @notice ERC721A with the MagicEden conduit preapproved.
 */
abstract contract ERC721AConduitPreapprovedCloneable is ERC721AQueryableCloneable {
    /// @dev The canonical MagicEden conduit.
    address internal constant _CONDUIT = 0x2052f8A2Ff46283B30084e5d84c89A2fdBE7f74b;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the
     *      assets of `owner`. Always returns true for the conduit.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(ERC721A, IERC721A)
        returns (bool)
    {
        if (operator == _CONDUIT) {
            return true;
        }
        return ERC721A.isApprovedForAll(owner, operator);
    }
}
