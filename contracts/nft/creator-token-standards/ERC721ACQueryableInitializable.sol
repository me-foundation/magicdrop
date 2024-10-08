// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@limitbreak/creator-token-standards/src/utils/CreatorTokenBase.sol";
import "erc721a-upgradeable/contracts/extensions/ERC721AQueryableUpgradeable.sol";
import "@limitbreak/creator-token-standards/src/utils/AutomaticValidatorTransferApproval.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title ERC721ACQueryableInitializable
 * @dev This contract is not meant for use in Upgradeable Proxy contracts though it may base on Upgradeable contract. The purpose of this
 * contract is for use with EIP-1167 Minimal Proxies (Clones).
 */
abstract contract ERC721ACQueryableInitializable is
    ERC721AQueryableUpgradeable,
    CreatorTokenBase,
    AutomaticValidatorTransferApproval,
    Initializable
{
    /// @notice Initializes the contract with the given name and symbol.
    function __ERC721ACQueryableInitializable_init(string memory name_, string memory symbol_) public {
        __ERC721A_init_unchained(name_, symbol_);
        __ERC721AQueryable_init_unchained();

        _emitDefaultTransferValidator();
        _registerTokenType(getTransferValidator());
    }

    /// @notice Overrides behavior of supportsInterface such that the contract implements the ICreatorToken interface.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721AUpgradeable, IERC721AUpgradeable) returns (bool) {
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
    function isApprovedForAll(address owner, address operator) public view virtual override(ERC721AUpgradeable, IERC721AUpgradeable) returns (bool isApproved) {
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

    function _msgSenderERC721A() internal view virtual override returns (address) {
        return _msgSender();
    }

    function _tokenType() internal pure override returns (uint16) {
        return uint16(721);
    }
}
