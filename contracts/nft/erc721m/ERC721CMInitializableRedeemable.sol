//SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import {ERC721CMInitializableV1_0_2} from "contracts/nft/erc721m/ERC721CMInitializableV1_0_2.sol";
import {AuthorizedRedeemerControl} from "contracts/common/AuthorizedRedeemerControl.sol";

/// @title ERC721CMInitializableV1_0_2
/// @notice An initializable ERC721AC contract with multi-stage minting, royalties, and authorized minters
/// @dev Implements ERC721ACQueryable, ERC2981, Ownable, ReentrancyGuard, and custom mintingØ logic
contract ERC721CMInitializableRedeemable is ERC721CMInitializableV1_0_2, AuthorizedRedeemerControl {
    /// @notice Revert when not the owner of the tokens
    error NotOwner();
    /// @notice Revert when the input arrays don't match in length
    error MismatchedArrays();

    /// @notice Emitted when a token is redeemed
    event TokenRedeemed(address from, uint256 tokenId);

    /// @notice Returns the contract name and version
    /// @return The contract name and version as strings
    function contractNameAndVersion() public pure override returns (string memory, string memory) {
        return ("ERC721CMInitializableRedeemable", "1.0.0");
    }

    /// @notice Burns a list of tokens.
    /// @dev Only callable by the REDEEMER_ROLE, no approval required. The token must exist.
    /// @param from The owners of the tokens to burn.
    /// @param tokenIds The IDs of the tokens to burn.
    function redeem(address[] memory from, uint256[] memory tokenIds) external onlyAuthorizedRedeemer {
        if (from.length != tokenIds.length || from.length == 0) {
            revert MismatchedArrays();
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (ownerOf(tokenIds[i]) != from[i]) {
                revert NotOwner();
            }
            _burn(tokenIds[i], false);
            emit TokenRedeemed(from[i], tokenIds[i]);
        }
    }

    /// @notice Adds an authorized redeemer
    /// @param redeemer The address to add as an authorized redeemer
    function addAuthorizedRedeemer(address redeemer) external override onlyOwner {
        _addAuthorizedRedeemer(redeemer);
    }

    /// @notice Removes an authorized redeemer
    /// @param redeemer The address to remove as an authorized redeemer
    function removeAuthorizedRedeemer(address redeemer) external override onlyOwner {
        _removeAuthorizedRedeemer(redeemer);
    }
}
