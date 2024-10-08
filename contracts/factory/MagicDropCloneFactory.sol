// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "solady/src/utils/UUPSUpgradeable.sol";
import {Initializable} from "solady/src/utils/Initializable.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {LibClone} from "solady/src/utils/LibClone.sol";
import {TokenStandard} from "../common/Structs.sol";
import {MagicDropTokenImplRegistry} from "../registry/MagicDropTokenImplRegistry.sol";

/// @title MagicDropCloneFactory
/// @notice A factory contract for creating and managing clones of MagicDrop contracts
/// @dev This contract uses the UUPS proxy pattern and is initializable
contract MagicDropCloneFactory is Initializable, Ownable, UUPSUpgradeable {
    /*==============================================================
    =                           CONSTANTS                          =
    ==============================================================*/

    MagicDropTokenImplRegistry private _registry;
    bytes4 private constant INITIALIZE_SELECTOR = bytes4(keccak256("initialize(string,string,address)"));

    /*==============================================================
    =                            STRUCTS                           =
    ==============================================================*/

    struct MagicDropFactoryStorage {
        mapping(bytes32 => bool) usedSalts;
    }

    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    // keccak256(abi.encode(uint256(keccak256("magicdrop.factory.MagicDropCloneFactory")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MAGICDROP_FACTORY_STORAGE =
        0xc982f4ee776d5a4a389c53cdba6d233ccdaf1824e9a3b0f1ea8fce06f767d800;

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    event MagicDropFactoryInitialized();
    event NewContractInitialized(
        address contractAddress, address initialOwner, uint32 implId, TokenStandard standard, string name, string symbol
    );

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    error ImplementationNotRegistered();
    error InitializationFailed();
    error SaltAlreadyUsed();
    error ContractAlreadyDeployed(address deployedAddress);
    error RegistryAddressCannotBeZero();
    error ImplementationDeprecated();

    /*==============================================================
    =                          INITIALIZER                         =
    ==============================================================*/

    /// @notice Initializes the contract
    /// @param initialOwner The address of the initial owner
    /// @param registry The address of the registry contract
    /// @dev This function can only be called once
    function initialize(address initialOwner, address registry) public initializer {
        if (registry == address(0)) {
            revert RegistryAddressCannotBeZero();
        }

        _registry = MagicDropTokenImplRegistry(registry);
        _initializeOwner(initialOwner);

        emit MagicDropFactoryInitialized();
    }

    /*==============================================================
    =                      PUBLIC WRITE METHODS                    =
    ==============================================================*/

    /// @notice Creates a new deterministic clone of a MagicDrop contract
    /// @param name The name of the new contract
    /// @param symbol The symbol of the new contract
    /// @param standard The token standard of the new contract
    /// @param initialOwner The initial owner of the new contract
    /// @param implId The implementation ID
    /// @param salt A unique salt for deterministic address generation
    /// @return The address of the newly created contract
    function createContractDeterministic(
        string calldata name,
        string calldata symbol,
        TokenStandard standard,
        address payable initialOwner,
        uint32 implId,
        bytes32 salt
    ) external returns (address) {
        // Retrieve the implementation address from the registry
        (address impl, bool deprecated) = _registry.getImplementation(standard, implId);

        if (deprecated) {
            revert ImplementationDeprecated();
        }

        if (impl == address(0)) {
            revert ImplementationNotRegistered();
        }

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, salt)
            mstore(0x20, MAGICDROP_FACTORY_STORAGE)
            let saltUsed := sload(keccak256(0x00, 0x40)) // usedSalts[salt]

            if saltUsed {
                mstore(0x00, 0x0ced3043) // SaltAlreadyUsed()
                revert(0x1c, 0x04)
            }
        }

        // Predict the address where the contract will be deployed
        address predictedAddress = LibClone.predictDeterministicAddress(impl, salt, address(this));

        // Check if a contract already exists at the predicted address
        if (predictedAddress.code.length > 0) {
            revert ContractAlreadyDeployed(predictedAddress);
        }

        // Create a deterministic clone of the implementation contract
        address instance = LibClone.cloneDeterministic(impl, salt);

        // Initialize the newly created contract
        (bool success,) = instance.call(abi.encodeWithSelector(INITIALIZE_SELECTOR, name, symbol, initialOwner));
        if (!success) {
            revert InitializationFailed();
        }

        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, salt)
            mstore(0x20, MAGICDROP_FACTORY_STORAGE)
            sstore(keccak256(0x00, 0x40), 1) // usedSalts[salt] = true
        }

        emit NewContractInitialized({
            contractAddress: instance,
            initialOwner: initialOwner,
            implId: implId,
            standard: standard,
            name: name,
            symbol: symbol
        });

        return instance;
    }

    /// @notice Creates a new clone of a MagicDrop contract
    /// @param name The name of the new contract
    /// @param symbol The symbol of the new contract
    /// @param standard The token standard of the new contract
    /// @param initialOwner The initial owner of the new contract
    /// @param implId The implementation ID
    /// @return The address of the newly created contract
    function createContract(
        string calldata name,
        string calldata symbol,
        TokenStandard standard,
        address payable initialOwner,
        uint32 implId
    ) external returns (address) {
        // Retrieve the implementation address from the registry
        (address impl, bool deprecated) = _registry.getImplementation(standard, implId);

        if (deprecated) {
            revert ImplementationDeprecated();
        }

        if (impl == address(0)) {
            revert ImplementationNotRegistered();
        }

        // Create a non-deterministic clone of the implementation contract
        address instance = LibClone.clone(impl);

        // Initialize the newly created contract
        (bool success,) = instance.call(abi.encodeWithSelector(INITIALIZE_SELECTOR, name, symbol, initialOwner));
        if (!success) {
            revert InitializationFailed();
        }

        emit NewContractInitialized({
            contractAddress: instance,
            initialOwner: initialOwner,
            implId: implId,
            standard: standard,
            name: name,
            symbol: symbol
        });

        return instance;
    }

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    /// @notice Predicts the deployment address of a deterministic clone
    /// @param standard The token standard of the contract
    /// @param implId The implementation ID
    /// @param salt The salt used for address generation
    /// @return The predicted deployment address
    function predictDeploymentAddress(TokenStandard standard, uint32 implId, bytes32 salt)
        external
        view
        returns (address)
    {
        (address impl, bool deprecated) = _registry.getImplementation(standard, implId);

        if (deprecated) {
            revert ImplementationDeprecated();
        }

        if (impl == address(0)) {
            revert ImplementationNotRegistered();
        }

        return LibClone.predictDeterministicAddress(impl, salt, address(this));
    }

    /// @notice Checks if a salt has been used
    /// @param salt The salt to check
    /// @return saltUsed Whether the salt has been used
    function isSaltUsed(bytes32 salt) external view returns (bool saltUsed) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, salt)
            mstore(0x20, MAGICDROP_FACTORY_STORAGE)
            let slot := keccak256(0x00, 0x40)
            saltUsed := sload(slot)
        }
    }

    /// @notice Retrieves the address of the registry contract
    /// @return The address of the registry contract
    function getRegistry() external view returns (address) {
        return address(_registry);
    }

    /*==============================================================
    =                      ADMIN OPERATIONS                        =
    ==============================================================*/

    ///@dev Internal function to authorize an upgrade.
    ///@param newImplementation Address of the new implementation.
    ///@notice Only the contract owner can upgrade the contract.
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
