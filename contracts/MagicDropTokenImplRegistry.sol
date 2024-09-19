// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "./interfaces/IMagicDropTokenImplRegistry.sol";
import {TokenStandard} from "./common/Structs.sol";

/**
 * @title MagicDropTokenImplRegistry
 * @dev A registry for managing token implementation addresses for different token standards.
 * This contract is upgradeable and uses the UUPS pattern.
 */
contract MagicDropTokenImplRegistry is IMagicDropTokenImplRegistry, UUPSUpgradeable, Ownable2StepUpgradeable {
    mapping(TokenStandard => mapping(uint256 => address)) private implementations;
    mapping(TokenStandard => uint256) private nextImplId;

    /**
     * @dev Initializes the contract, setting up the owner and UUPS upgradeability.
     * This function replaces the constructor for upgradeable contracts.
     */
    function initialize() public initializer {
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        // Initialize nextImplId for each token standard to 1
        nextImplId[TokenStandard.ERC721] = 1;
        nextImplId[TokenStandard.ERC1155] = 1;
    }

    /**
     * @dev Registers a new implementation for a given token standard.
     * @param standard The token standard (ERC721, ERC1155).
     * @param impl The address of the implementation contract.
     * @notice Only the contract owner can call this function.
     * @notice Reverts if an implementation with the same name is already registered.
     */
    function registerImplementation(TokenStandard standard, address impl) external onlyOwner returns (uint256) {
        uint256 implId = nextImplId[standard];
        implementations[standard][implId] = impl;
        nextImplId[standard] = implId + 1;
        emit ImplementationRegistered(standard, impl, implId);
        return implId;
    }

    /**
     * @dev Unregisters an implementation for a given token standard.
     * @param standard The token standard (ERC721, ERC1155).
     * @param implId The ID of the implementation to unregister.
     * @notice Only the contract owner can call this function.
     * @notice Reverts if the implementation is not registered.
     */
    function unregisterImplementation(TokenStandard standard, uint256 implId) external onlyOwner {
        if (implementations[standard][implId] == address(0)) {
            revert ImplementationNotRegistered();
        }
        delete implementations[standard][implId];
        emit ImplementationUnregistered(standard, implId);
    }

    /**
     * @dev Retrieves the implementation address for a given token standard and implementation name.
     * @param standard The token standard (ERC20, ERC721, ERC1155).
     * @param implId The ID of the implementation.
     * @return The address of the implementation contract.
     */
    function getImplementation(TokenStandard standard, uint256 implId) external view returns (address) {
        return implementations[standard][implId];
    }

    /**
     * @dev Internal function to authorize an upgrade.
     * @param newImplementation Address of the new implementation.
     * @notice Only the contract owner can upgrade the contract.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
