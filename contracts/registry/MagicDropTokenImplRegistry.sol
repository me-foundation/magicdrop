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
        mapping(uint256 => address) implementations;
        mapping(uint256 => bool) deprecatedImplementations;
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
    event ImplementationDeprecated(TokenStandard standard, uint32 implId);

    /*==============================================================
    =                            ERRORS                            =
    ==============================================================*/

    error ImplementationNotRegistered();
    error ImplementationAlreadyDeprecated();
    error ImplementationDoesNotSupportStandard(TokenStandard standard);
    error UnsupportedTokenStandard(TokenStandard standard);

    /*==============================================================
    =                          INITIALIZER                         =
    ==============================================================*/

    /// @dev Disables initializers to ensure this contract is used by a proxy
    constructor() {
        _disableInitializers();
    }

    /// @dev Initializes the contract, setting up the owner and UUPS upgradeability.
    /// This function replaces the constructor for upgradeable contracts.
    function initialize(address initialOwner) public initializer {
        _initializeOwner(initialOwner);

        // Initialize nextImplId and interface IDs for each token standard
        RegistryStorage storage data = _loadRegistryStorage();
        data.tokenStandardData[TokenStandard.ERC721].nextImplId = 1;
        data.tokenStandardData[TokenStandard.ERC721].interfaceId = 0x80ac58cd; // ERC721 interface ID

        data.tokenStandardData[TokenStandard.ERC1155].nextImplId = 1;
        data.tokenStandardData[TokenStandard.ERC1155].interfaceId = 0xd9b67a26; // ERC1155 interface ID
    }

    /*==============================================================
    =                      PUBLIC WRITE METHODS                    =
    ==============================================================*/

    /// @dev Registers a new implementation for a given token standard.
    /// @param standard The token standard (ERC721, ERC1155).
    /// @param impl The address of the implementation contract.
    /// @notice Only the contract owner can call this function.
    /// @notice Reverts if an implementation with the same name is already registered.
    function registerImplementation(TokenStandard standard, address impl) external onlyOwner returns (uint32) {
        RegistryStorage storage data = _loadRegistryStorage();
        bytes4 interfaceId = data.tokenStandardData[standard].interfaceId;
        if (interfaceId == 0) {
            revert UnsupportedTokenStandard(standard);
        }

        if (!IERC165(impl).supportsInterface(interfaceId)) {
            revert ImplementationDoesNotSupportStandard(standard);
        }

        uint32 implId = data.tokenStandardData[standard].nextImplId;
        data.tokenStandardData[standard].implementations[implId] = impl;
        data.tokenStandardData[standard].nextImplId = implId + 1;
        emit ImplementationRegistered(standard, impl, implId);
        return implId;
    }

    /// @dev Deprecates an implementation for a given token standard.
    /// @param standard The token standard (ERC721, ERC1155).
    /// @param implId The ID of the implementation to deprecate.
    /// @notice Only the contract owner can call this function.
    /// @notice Reverts if the implementation is not registered or already deprecated.
    function deprecateImplementation(TokenStandard standard, uint32 implId) external onlyOwner {
        RegistryStorage storage data = _loadRegistryStorage();
        if (data.tokenStandardData[standard].implementations[implId] == address(0)) {
            revert ImplementationNotRegistered();
        }

        if (data.tokenStandardData[standard].deprecatedImplementations[implId]) {
            revert ImplementationAlreadyDeprecated();
        }

        data.tokenStandardData[standard].deprecatedImplementations[implId] = true;

        emit ImplementationDeprecated(standard, implId);
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @dev Retrieves the implementation address for a given token standard and implementation ID.
    /// @param standard The token standard (ERC721, ERC1155).
    /// @param implId The ID of the implementation.
    /// @return implAddress The address of the implementation contract.
    /// @return isDeprecated Whether the implementation is deprecated.
    function getImplementation(TokenStandard standard, uint32 implId)
        external
        view
        returns (address implAddress, bool isDeprecated)
    {
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

            // Compute storage slot for deprecatedImplementations[implId]
            mstore(0x00, implId)
            mstore(0x20, add(s1, 2))
            let deprecatedImplSlot := keccak256(0x00, 0x40)
            isDeprecated := sload(deprecatedImplSlot)
        }
    }

    /*==============================================================
    =                       INTERNAL HELPERS                       =
    ==============================================================*/

    /// @dev Loads the registry storage.
    /// @return $ The registry storage.
    function _loadRegistryStorage() private pure returns (RegistryStorage storage $) {
        assembly {
            $.slot := MAGICDROP_REGISTRY_STORAGE
        }
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    /// @dev Internal function to authorize an upgrade.
    /// @param newImplementation Address of the new implementation.
    /// @notice Only the contract owner can upgrade the contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
