// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

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
    =                             EVENTS                           =
    ==============================================================*/

    event MagicDropFactoryInitialized();
    event NewContractInitialized(
        address contractAddress, address initialOwner, uint32 implId, TokenStandard standard, string name, string symbol
    );
    event Withdrawal(address to, uint256 amount);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    error InitializationFailed();
    error RegistryAddressCannotBeZero();
    error InsufficientDeploymentFee();
    error WithdrawalFailed();

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
    ) external payable returns (address) {
        address impl;
        // Retrieve the implementation address from the registry
        if (implId == 0) {
            impl = _registry.getDefaultImplementation(standard);
        } else {
            impl = _registry.getImplementation(standard, implId);
        }

        // Retrieve the deployment fee for the implementation and ensure the caller has sent the correct amount
        uint256 deploymentFee = _registry.getDeploymentFee(standard, implId);
        if (msg.value < deploymentFee) {
            revert InsufficientDeploymentFee();
        }

        // Create a deterministic clone of the implementation contract
        address instance = LibClone.cloneDeterministic(impl, salt);

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
    ) external payable returns (address) {
        address impl;
        // Retrieve the implementation address from the registry
        if (implId == 0) {
            impl = _registry.getDefaultImplementation(standard);
        } else {
            impl = _registry.getImplementation(standard, implId);
        }

        // Retrieve the deployment fee for the implementation and ensure the caller has sent the correct amount
        uint256 deploymentFee = _registry.getDeploymentFee(standard, implId);
        if (msg.value < deploymentFee) {
            revert InsufficientDeploymentFee();
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
        address impl;
        if (implId == 0) {
            impl = _registry.getDefaultImplementation(standard);
        } else {
            impl = _registry.getImplementation(standard, implId);
        }
        return LibClone.predictDeterministicAddress(impl, salt, address(this));
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

    /// @notice Withdraws the contract's balance
    function withdraw(address to) external onlyOwner {
        (bool success,) = to.call{value: address(this).balance}("");
        if (!success) {
            revert WithdrawalFailed();
        }

        emit Withdrawal(to, address(this).balance);
    }

    /// @notice Receives ETH
    receive() external payable {}

    /// @notice Fallback function to receive ETH
    fallback() external payable {}
}