// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@limitbreak/creator-token-standards/src/utils/CreatorTokenBase.sol";
import "@limitbreak/creator-token-standards/src/utils/AutomaticValidatorTransferApproval.sol";

import {ERC721A, IERC721A} from "erc721a/contracts/ERC721A.sol";

import "contracts/nft/erc721m/clones/ERC721AConduitPreapprovedCloneable.sol";

/// @title ERC721ACQueryableInitializable
/// @notice An ERC721AC extension with queryable and initialization features.
/// @dev The purpose of this contract is for use with EIP-1167 Minimal Proxies (Clones).
abstract contract ERC721ACQueryableInitializable is
    ERC721AConduitPreapprovedCloneable,
    CreatorTokenBase,
    AutomaticValidatorTransferApproval
{
    /// @notice Initializes the contract with the given name and symbol.
    function __ERC721ACQueryableInitializable_init(string memory name_, string memory symbol_) public {
        __ERC721ACloneable__init(name_, symbol_);

        _emitDefaultTransferValidator();
        _registerTokenType(getTransferValidator());
    }

    /// @notice Overrides behavior of supportsInterface such that the contract implements the ICreatorToken interface.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721ACloneable, IERC721A)
        returns (bool)
    {
        return interfaceId == type(ICreatorToken).interfaceId || interfaceId == type(ICreatorTokenLegacy).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice Returns the function selector for the transfer validator's validation function to be called
    /// @notice for transaction simulation.
    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /// @notice Overrides behavior of isApprovedFor all such that if an operator is not explicitly approved
    /// @notice for all, the contract owner can optionally auto-approve the 721-C transfer validator for transfers.
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool isApproved) {
        isApproved = super.isApprovedForAll(owner, operator);

        if (!isApproved) {
            if (autoApproveTransfersFromValidator) {
                isApproved = operator == address(getTransferValidator());
            }
        }
    }

    /// @dev Ties the erc721a _beforeTokenTransfers hook to more granular transfer validation logic
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        virtual
        override
    {
        for (uint256 i = 0; i < quantity;) {
            _validateBeforeTransfer(from, to, startTokenId + i);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Ties the erc721a _afterTokenTransfer hook to more granular transfer validation logic
    function _afterTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        virtual
        override
    {
        for (uint256 i = 0; i < quantity;) {
            _validateAfterTransfer(from, to, startTokenId + i);
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Get the total minted count (including burned)
    /// @return The total minted count
    function totalMinted() public view returns (uint256) {
        return _totalMinted();
    }

    function _msgSenderERC721A() internal view virtual override returns (address) {
        return _msgSender();
    }

    function _tokenType() internal pure override returns (uint16) {
        return uint16(721);
    }
}
