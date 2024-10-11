// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/src/utils/UUPSUpgradeable.sol";
import {IMagicDropTokenImplRegistry, TokenStandard} from "./interfaces/IMagicDropTokenImplRegistry.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title MagicDropTokenImplRegistry
/// @dev A registry for managing token implementation addresses for different token standards.
/// This contract is upgradeable and uses the UUPS pattern.
contract MagicDropTokenImplRegistry is Initializable, UUPSUpgradeable, Ownable, IMagicDropTokenImplRegistry {
    /*==============================================================
    =                            STRUCTS                           =
    ==============================================================*/

    struct RegistryData {
        bytes4 interfaceId;
        uint32 nextImplId;
        uint32 defaultImplId;
        mapping(uint256 => address) implementations;
    }

    struct RegistryStorage {
        mapping(TokenStandard => RegistryData) tokenStandardData;
    }

    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    // keccak256(abi.encode(uint256(keccak256("magicdrop.registry.MagicDropTokenImplRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MAGICDROP_REGISTRY_STORAGE =
        0xfd008fcd1deb21680f735a35fafc51691c5fb3daec313cfea4dc62938bee9000;

    /*==============================================================
    =                            EVENTS                            =
    ==============================================================*/

    event ImplementationRegistered(TokenStandard standard, address impl, uint32 implId);
    event ImplementationUnregistered(TokenStandard standard, uint32 implId);
    event DefaultImplementationSet(TokenStandard standard, uint32 implId);

    /*==============================================================
    =                            ERRORS                            =
    ==============================================================*/

    error InvalidImplementation();
    error ImplementationDoesNotSupportStandard();
    error UnsupportedTokenStandard();
    error DefaultImplementationNotRegistered();

    /*==============================================================
    =                          INITIALIZER                         =
    ==============================================================*/

    /// @dev Initializes the contract, setting up the owner and UUPS upgradeability.
    /// This function replaces the constructor for upgradeable contracts.
    function initialize(address initialOwner) public initializer {
        _initializeOwner(initialOwner);

        // Initialize nextImplId and interface IDs for each token standard
        RegistryStorage storage $ = _loadRegistryStorage();
        $.tokenStandardData[TokenStandard.ERC721].nextImplId = 1;
        $.tokenStandardData[TokenStandard.ERC721].interfaceId = 0x80ac58cd; // ERC721 interface ID

        $.tokenStandardData[TokenStandard.ERC1155].nextImplId = 1;
        $.tokenStandardData[TokenStandard.ERC1155].interfaceId = 0xd9b67a26; // ERC1155 interface ID
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @dev Retrieves the implementation address for a given token standard and implementation ID.
    /// @param standard The token standard (ERC721, ERC1155).
    /// @param implId The ID of the implementation.
    /// @notice Reverts if the implementation is not registered.
    /// @return implAddress The address of the implementation contract.
    function getImplementation(TokenStandard standard, uint32 implId) external view returns (address implAddress) {
        assembly {
            // Compute s1 = keccak256(abi.encode(standard, MAGICDROP_REGISTRY_STORAGE))
            mstore(0x00, standard)
            mstore(0x20, MAGICDROP_REGISTRY_STORAGE)
            let s1 := keccak256(0x00, 0x40)

            // Compute storage slot for implementations[implId]
            mstore(0x00, implId)
            mstore(0x20, add(s1, 1))
            let implSlot := keccak256(0x00, 0x40)
            implAddress := sload(implSlot)

            // Revert if the implementation is not registered
            if iszero(implAddress) {
                mstore(0x00, 0x68155f9a) // revert InvalidImplementation()
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Gets the default implementation ID for a given token standard
    /// @param standard The token standard (ERC721, ERC1155)
    /// @notice Reverts if the default implementation is not registered.
    /// @return defaultImplId The default implementation ID for the given standard
    function getDefaultImplementationID(TokenStandard standard) external view returns (uint32 defaultImplId) {
        assembly {
            // Compute storage slot for tokenStandardData[standard]
            mstore(0x00, standard)
            mstore(0x20, MAGICDROP_REGISTRY_STORAGE)
            let slot := keccak256(0x00, 0x40)

            // Extract 'defaultImplId' by shifting and masking
            // Shift right by 64 bits to bring 'defaultImplId' to bits 0-31
            let shiftedData := shr(64, sload(slot))
            // Mask to extract the lower 32 bits
            defaultImplId := and(shiftedData, 0xffffffff)

            // Check if defaultImplId is 0 and revert if so
            if iszero(defaultImplId) {
                // Prepare error message for DefaultImplementationNotRegistered(TokenStandard)
                mstore(0x00, 0x161378fc)
                revert(0x1c, 0x04)
            }
        }
    }

    /// @dev Gets the default implementation address for a given token standard
    /// @param standard The token standard (ERC721, ERC1155)
    /// @notice Reverts if the default implementation is not registered.
    /// @return implAddress The default implementation address for the given standard
    function getDefaultImplementation(TokenStandard standard) external view returns (address implAddress) {
        assembly {
            mstore(0x00, standard)
            mstore(0x20, MAGICDROP_REGISTRY_STORAGE)
            let slot := keccak256(0x00, 0x40)

            // Extract 'defaultImplId' by shifting and masking
            // Shift right by 64 bits to bring 'defaultImplId' to bits 0-31
            let shiftedData := shr(64, sload(slot))
            // Mask to extract the lower 32 bits
            let defaultImplId := and(shiftedData, 0xffffffff)

            // Revert if the default implementation is not registered
            if iszero(defaultImplId) {
                // revert DefaultImplementationNotRegistered()
                mstore(0x00, 0x161378fc)
                revert(0x1c, 0x04)
            }

            // Compute storage slot for implementations[defaultImplId]
            mstore(0x00, defaultImplId)
            mstore(0x20, add(slot, 1))
            let implSlot := keccak256(0x00, 0x40)
            implAddress := sload(implSlot)
        }
    }

    /*==============================================================
    =                       INTERNAL HELPERS                       =
    ==============================================================*/

    /// @dev Loads the registry storage.
    /// @return $ The registry storage.
    function _loadRegistryStorage() internal pure returns (RegistryStorage storage $) {
        assembly {
            $.slot := MAGICDROP_REGISTRY_STORAGE
        }
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @dev Registers a new implementation for a given token standard.
    /// @param standard The token standard (ERC721, ERC1155).
    /// @param impl The address of the implementation contract.
    /// @param isDefault Whether the implementation should be set as the default implementation
    /// @notice Only the contract owner can call this function.
    /// @notice Reverts if an implementation with the same name is already registered.
    /// @return The ID of the newly registered implementation
    function registerImplementation(TokenStandard standard, address impl, bool isDefault)
        external
        onlyOwner
        returns (uint32)
    {
        RegistryStorage storage $ = _loadRegistryStorage();
        bytes4 interfaceId = $.tokenStandardData[standard].interfaceId;
        if (interfaceId == 0) {
            revert UnsupportedTokenStandard();
        }

        if (!IERC165(impl).supportsInterface(interfaceId)) {
            revert ImplementationDoesNotSupportStandard();
        }

        uint32 implId = $.tokenStandardData[standard].nextImplId;
        $.tokenStandardData[standard].implementations[implId] = impl;
        $.tokenStandardData[standard].nextImplId = implId + 1;
        emit ImplementationRegistered(standard, impl, implId);

        if (isDefault) {
            $.tokenStandardData[standard].defaultImplId = implId;
            emit DefaultImplementationSet(standard, implId);
        }

        return implId;
    }

    /// @dev Unregisters an implementation for a given token standard.
    /// @param standard The token standard (ERC721, ERC1155).
    /// @param implId The ID of the implementation to unregister.
    /// @notice Only the contract owner can call this function.
    /// @notice Reverts if the implementation is not registered.
    function unregisterImplementation(TokenStandard standard, uint32 implId) external onlyOwner {
        RegistryStorage storage $ = _loadRegistryStorage();
        address implData = $.tokenStandardData[standard].implementations[implId];

        if (implData == address(0)) {
            revert InvalidImplementation();
        }

        $.tokenStandardData[standard].implementations[implId] = address(0);

        if ($.tokenStandardData[standard].defaultImplId == implId) {
            $.tokenStandardData[standard].defaultImplId = 0;
            emit DefaultImplementationSet(standard, 0);
        }

        emit ImplementationUnregistered(standard, implId);
    }

    /// @dev Sets the default implementation ID for a given token standard
    /// @param standard The token standard (ERC721, ERC1155)
    /// @param implId The ID of the implementation to set as default
    /// @notice Reverts if the implementation is not registered.
    /// @notice Only the contract owner can call this function
    function setDefaultImplementation(TokenStandard standard, uint32 implId) external onlyOwner {
        RegistryStorage storage $ = _loadRegistryStorage();
        address implData = $.tokenStandardData[standard].implementations[implId];

        if (implData == address(0)) {
            revert InvalidImplementation();
        }

        $.tokenStandardData[standard].defaultImplId = implId;

        emit DefaultImplementationSet(standard, implId);
    }

    /// @dev Internal function to authorize an upgrade.
    /// @param newImplementation Address of the new implementation.
    /// @notice Only the contract owner can upgrade the contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
