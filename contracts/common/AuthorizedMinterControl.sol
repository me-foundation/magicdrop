// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

///@title AuthorizedMinterControl
///@dev Abstract contract to manage authorized minters for MagicDrop tokens
abstract contract AuthorizedMinterControl {
    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    mapping(address => bool) private _authorizedMinters;

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    event AuthorizedMinterAdded(address indexed minter);
    event AuthorizedMinterRemoved(address indexed minter);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    error NotAuthorized();

    /*==============================================================
    =                           MODIFIERS                          =
    ==============================================================*/

    ///@dev Modifier to check if the sender is an authorized minter
    modifier onlyAuthorizedMinter() {
        if (!_authorizedMinters[msg.sender]) revert NotAuthorized();
        _;
    }

    /*==============================================================
    =                      PUBLIC WRITE METHODS                    =
    ==============================================================*/

    ///@dev Add an authorized minter.
    ///@dev Please override this function to check if `msg.sender` is authorized
    ///@param minter Address to be added as an authorized minter
    function addAuthorizedMinter(address minter) external virtual;

    ///@dev Remove an authorized minter.
    ///@dev Please override this function to check if `msg.sender` is authorized
    ///@param minter Address to be removed from authorized minters
    function removeAuthorizedMinter(address minter) external virtual;

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    ///@dev Check if an address is an authorized minter
    ///@param minter Address to check
    ///@return bool True if the address is an authorized minter, false otherwise
    function isAuthorizedMinter(address minter) public view returns (bool) {
        return _authorizedMinters[minter];
    }

    /*==============================================================
    =                       INTERNAL HELPERS                       =
    ==============================================================*/

    ///@dev Internal function to add an authorized minter
    ///@param minter Address to be added as an authorized minter
    function _addAuthorizedMinter(address minter) internal {
        _authorizedMinters[minter] = true;
        emit AuthorizedMinterAdded(minter);
    }

    ///@dev Internal function to remove an authorized minter
    ///@param minter Address to be removed from authorized minters
    function _removeAuthorizedMinter(address minter) internal {
        _authorizedMinters[minter] = false;
        emit AuthorizedMinterRemoved(minter);
    }
}
