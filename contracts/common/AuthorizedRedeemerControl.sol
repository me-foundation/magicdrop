// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

///@title AuthorizedRedeemerControl
///@dev Abstract contract to manage authorized redeemers for MagicDrop tokens
abstract contract AuthorizedRedeemerControl {
    /*==============================================================
    =                            STORAGE                           =
    ==============================================================*/

    mapping(address => bool) private _authorizedRedeemers;

    /*==============================================================
    =                             EVENTS                           =
    ==============================================================*/

    event AuthorizedRedeemerAdded(address indexed redeemer);
    event AuthorizedRedeemerRemoved(address indexed redeemer);

    /*==============================================================
    =                             ERRORS                           =
    ==============================================================*/

    error NotAuthorizedRedeemer();

    /*==============================================================
    =                           MODIFIERS                          =
    ==============================================================*/

    ///@dev Modifier to check if the sender is an authorized redeemer
    modifier onlyAuthorizedRedeemer() {
        if (!_authorizedRedeemers[msg.sender]) revert NotAuthorizedRedeemer();
        _;
    }

    /*==============================================================
    =                      PUBLIC WRITE METHODS                    =
    ==============================================================*/

    ///@dev Add an authorized redeemer.
    ///@dev Please override this function to check if `msg.sender` is authorized
    ///@param redeemer Address to be added as an authorized redeemer
    function addAuthorizedRedeemer(address redeemer) external virtual;

    ///@dev Remove an authorized redeemer.
    ///@dev Please override this function to check if `msg.sender` is authorized
    ///@param redeemer Address to be removed from authorized redeemers
    function removeAuthorizedRedeemer(address redeemer) external virtual;

    /*==============================================================
    =                      PUBLIC VIEW METHODS                     =
    ==============================================================*/

    ///@dev Check if an address is an authorized redeemer
    ///@param redeemer Address to check
    ///@return bool True if the address is an authorized redeemer, false otherwise
    function isAuthorizedRedeemer(address redeemer) public view returns (bool) {
        return _authorizedRedeemers[redeemer];
    }

    /*==============================================================
    =                       INTERNAL HELPERS                       =
    ==============================================================*/

    ///@dev Internal function to add an authorized redeemer
    ///@param redeemer Address to be added as an authorized redeemer
    function _addAuthorizedRedeemer(address redeemer) internal {
        _authorizedRedeemers[redeemer] = true;
        emit AuthorizedRedeemerAdded(redeemer);
    }

    ///@dev Internal function to remove an authorized redeemer
    ///@param redeemer Address to be removed from authorized redeemers
    function _removeAuthorizedRedeemer(address redeemer) internal {
        _authorizedRedeemers[redeemer] = false;
        emit AuthorizedRedeemerRemoved(redeemer);
    }
}
