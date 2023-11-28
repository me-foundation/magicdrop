// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/creator-token-standards/access/OwnablePermissions.sol";
import "contracts/creator-token-standards/interfaces/ICreatorToken.sol";
import "contracts/creator-token-standards/interfaces/ICreatorTokenTransferValidatorV2.sol";
import "contracts/creator-token-standards/utils/TransferValidation.sol";
import "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title CreatorTokenBaseV2
 * @author Limit Break, Inc.
 * @notice CreatorTokenBaseV2 is an abstract contract that provides basic functionality for managing token 
 * transfer policies through an implementation of ICreatorTokenTransferValidator/ICreatorTokenTransferValidatorV2. 
 * This contract is intended to be used as a base for creator-specific token contracts, enabling customizable transfer 
 * restrictions and security policies.
 *
 * <h4>Features:</h4>
 * <ul>Ownable: This contract can have an owner who can set and update the transfer validator.</ul>
 * <ul>TransferValidation: Implements the basic token transfer validation interface.</ul>
 * <ul>ICreatorTokenV2: Implements the interface for creator tokens, providing view functions for token security policies.</ul>
 *
 * <h4>Benefits:</h4>
 * <ul>Provides a flexible and modular way to implement custom token transfer restrictions and security policies.</ul>
 * <ul>Allows creators to enforce policies such as account and codehash blacklists and whitelists.</ul>
 * <ul>Can be easily integrated into other token contracts as a base contract.</ul>
 *
 * <h4>Intended Usage:</h4>
 * <ul>Use as a base contract for creator token implementations that require advanced transfer restrictions and 
 *   security policies.</ul>
 * <ul>Set and update the ICreatorTokenTransferValidator implementation contract to enforce desired policies for the 
 *   creator token.</ul>
 *
 * <h4>Compatibility:</h4>
 * <ul>Backward and Forward Compatible - V1/V2 Creator Token Base will work with both V1 and V2 Transfer Validators.</ul>
 */
abstract contract CreatorTokenBaseV2 is OwnablePermissions, TransferValidation, ICreatorToken {

    error CreatorTokenBase__FunctionDeprecatedUseTransferValidatorInstead();
    error CreatorTokenBase__InvalidTransferValidatorContract();
    error CreatorTokenBase__SetTransferValidatorFirst();

    address public constant DEFAULT_TRANSFER_VALIDATOR = address(0xF2E246BB76DF876Cef8b38ae84130F4F55De395b);
    TransferSecurityLevels public constant DEFAULT_TRANSFER_SECURITY_LEVEL = TransferSecurityLevels.Recommended;
    uint120 public constant DEFAULT_LIST_ID = uint120(0);

    TransferValidatorReference private transferValidatorReference;

    /**
     * @notice Allows the contract owner to set the transfer validator to the official validator contract
     *         and set the security policy to the recommended default settings.
     * @dev    May be overridden to change the default behavior of an individual collection.
     */
    function setToDefaultSecurityPolicy() public virtual {
        _requireCallerIsContractOwner();
        setTransferValidator(DEFAULT_TRANSFER_VALIDATOR);

        ICreatorTokenTransferValidatorV2(DEFAULT_TRANSFER_VALIDATOR).
            setTransferSecurityLevelOfCollection(address(this), DEFAULT_TRANSFER_SECURITY_LEVEL);

        ICreatorTokenTransferValidatorV2(DEFAULT_TRANSFER_VALIDATOR).
            applyListToCollection(address(this), DEFAULT_LIST_ID);
    }

    /**
     * @notice Allows the contract owner to set the transfer validator to a custom validator contract
     *         and set the security policy to their own custom settings.
     */
    function setToCustomValidatorAndSecurityPolicy(
        address validator, 
        TransferSecurityLevels level, 
        uint120 listId
    ) public {
        _requireCallerIsContractOwner();

        setTransferValidator(validator);

        if (validator != address(0)) {
            ICreatorTokenTransferValidator(validator).setTransferSecurityLevelOfCollection(address(this), level);
            ICreatorTokenTransferValidator(validator).setOperatorWhitelistOfCollection(address(this), listId);
        }
    }

    /**
     * @notice Allows the contract owner to set the security policy to their own custom settings.
     * @dev    Reverts if the transfer validator has not been set.
     */
    function setToCustomSecurityPolicy(
        TransferSecurityLevels level, 
        uint120 listId
    ) public {
        _requireCallerIsContractOwner();

        ICreatorTokenTransferValidator validator = getTransferValidator();
        if (address(validator) == address(0)) {
            revert CreatorTokenBase__SetTransferValidatorFirst();
        }

        validator.setTransferSecurityLevelOfCollection(address(this), level);
        validator.setOperatorWhitelistOfCollection(address(this), listId);
    }

    /**
     * @notice Sets the transfer validator for the token contract.
     *
     * @dev    Throws when provided validator contract is not the zero address and doesn't support 
     *         the ICreatorTokenTransferValidator or ICreatorTokenTransferValidatorV2 interface. 
     * @dev    Throws when the caller is not the contract owner.
     *
     * @dev    <h4>Postconditions:</h4>
     *         1. The transferValidator address is updated.
     *         2. The `TransferValidatorUpdated` event is emitted.
     *
     * @param transferValidator_ The address of the transfer validator contract.
     */
    function setTransferValidator(address transferValidator_) public {
        _requireCallerIsContractOwner();

        bool isValidTransferValidator = false;
        uint16 version = 0;

        if(transferValidator_.code.length > 0) {
            try IERC165(transferValidator_).supportsInterface(type(ICreatorTokenTransferValidatorV2).interfaceId) 
                returns (bool supportsInterface) {
                isValidTransferValidator = supportsInterface;
                version = 2;
            } catch {}

            if (!isValidTransferValidator) {
                try IERC165(transferValidator_).supportsInterface(type(ICreatorTokenTransferValidator).interfaceId) 
                    returns (bool supportsInterface) {
                    isValidTransferValidator = supportsInterface;
                    version = 1;
                } catch {}
            }
        }

        if(transferValidator_ != address(0) && !isValidTransferValidator) {
            revert CreatorTokenBase__InvalidTransferValidatorContract();
        }

        emit TransferValidatorUpdated(address(getTransferValidator()), transferValidator_);

        transferValidatorReference = TransferValidatorReference({
            isInitialized: true,
            version: version,
            transferValidator: transferValidator_
        });
    }

    /**
     * @notice Returns the transfer validator contract address for this token contract.
     */
    function getTransferValidator() public view override returns (ICreatorTokenTransferValidator transferValidator) {
        transferValidator = ICreatorTokenTransferValidator(transferValidatorReference.transferValidator);

        if (address(transferValidator) == address(0)) {
            if (!transferValidatorReference.isInitialized) {
                transferValidator = ICreatorTokenTransferValidator(DEFAULT_TRANSFER_VALIDATOR);
            }
        }
    }

    /**
     * @notice Determines if a transfer is allowed based on the token contract's security policy.  Use this function
     *         to simulate whether or not a transfer made by the specified `caller` from the `from` address to the `to`
     *         address would be allowed by this token's security policy.
     *
     * @notice This function only checks the security policy restrictions and does not check whether token ownership
     *         or approvals are in place. 
     *
     * @param caller The address of the simulated caller.
     * @param from   The address of the sender.
     * @param to     The address of the receiver.
     * @return       True if the transfer is allowed, false otherwise.
     */
    function isTransferAllowed(address caller, address from, address to) public view override returns (bool) {
        ICreatorTokenTransferValidator transferValidator = getTransferValidator();

        if (address(transferValidator) != address(0)) {
            try transferValidator.applyCollectionTransferPolicy(caller, from, to) {
                return true;
            } catch {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Pre-validates a token transfer, reverting if the transfer is not allowed by this token's security policy.
     *      Inheriting contracts are responsible for overriding the _beforeTokenTransfer function, or its equivalent
     *      and calling _validateBeforeTransfer so that checks can be properly applied during token transfers.
     *
     * @dev Throws when the transfer doesn't comply with the collection's transfer policy, if the transferValidator is
     *      set to a non-zero address.
     *
     * @param caller  The address of the caller.
     * @param from    The address of the sender.
     * @param to      The address of the receiver.
     */
    function _preValidateTransfer(
        address caller, 
        address from, 
        address to, 
        uint256 /*tokenId*/, 
        uint256 /*value*/) internal virtual override {
        ICreatorTokenTransferValidator transferValidator = getTransferValidator();

        if (address(transferValidator) != address(0)) {
            transferValidator.applyCollectionTransferPolicy(caller, from, to);
        }
    }

    /*************************************************************************/
    /*                        BACKWARDS COMPATIBILITY                        */
    /*************************************************************************/

    /**
     * @notice Allows the contract owner to set the security policy to their own custom settings.
     * @dev    Reverts if the transfer validator has not been set.
     */
    function setToCustomSecurityPolicy(
        TransferSecurityLevels level, 
        uint120 operatorWhitelistId, 
        uint120 permittedContractReceiversAllowlistId) public {
        _requireCallerIsContractOwner();

        ICreatorTokenTransferValidator validator = getTransferValidator();
        if (address(validator) == address(0)) {
            revert CreatorTokenBase__SetTransferValidatorFirst();
        }

        validator.setTransferSecurityLevelOfCollection(address(this), level);
        validator.setOperatorWhitelistOfCollection(address(this), operatorWhitelistId);
        validator.setPermittedContractReceiverAllowlistOfCollection(address(this), permittedContractReceiversAllowlistId);
    }

    /**
     * @notice Allows the contract owner to set the transfer validator to a custom validator contract
     *         and set the security policy to their own custom settings.
     */
    function setToCustomValidatorAndSecurityPolicy(
        address validator, 
        TransferSecurityLevels level, 
        uint120 operatorWhitelistId, 
        uint120 permittedContractReceiversAllowlistId
    ) public {
        _requireCallerIsContractOwner();

        setTransferValidator(validator);

        if (validator != address(0)) {
            ICreatorTokenTransferValidator(validator).
                setTransferSecurityLevelOfCollection(address(this), level);

            ICreatorTokenTransferValidator(validator).
                setOperatorWhitelistOfCollection(address(this), operatorWhitelistId);

            ICreatorTokenTransferValidator(validator).
                setPermittedContractReceiverAllowlistOfCollection(address(this), permittedContractReceiversAllowlistId);
        }
    }

    /**
     * @notice Deprecated - Query On Transfer Validator Instead
     */
    function getSecurityPolicy() public view override throwsDeprecatedError returns (CollectionSecurityPolicy memory) {}

    /**
     * @notice Deprecated - Query On Transfer Validator Instead
     */
    function getWhitelistedOperators() public view override throwsDeprecatedError returns (address[] memory) {}

    /**
     * @notice Deprecated - Query On Transfer Validator Instead
     */
    function getPermittedContractReceivers() public view override throwsDeprecatedError returns (address[] memory) {}

    /**
     * @notice Deprecated - Query On Transfer Validator Instead
     */
    function isOperatorWhitelisted(address operator) public view override throwsDeprecatedError returns (bool) {}

    /**
     * @notice Deprecated - Query On Transfer Validator Instead
     */
    function isContractReceiverPermitted(address receiver) public view override throwsDeprecatedError returns (bool) {}

    modifier throwsDeprecatedError() {
        _throwDeprecatedError();
        _;
    }

    function _throwDeprecatedError() internal pure {
        revert CreatorTokenBase__FunctionDeprecatedUseTransferValidatorInstead();
    }
}
