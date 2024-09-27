pragma solidity ^0.8.20;

/**
 * @title AuthorizedMinterControl
 * @dev Abstract contract to manage authorized minters for ERC1155M tokens
 */
abstract contract AuthorizedMinterControl {
    mapping(address => bool) private _authorizedMinters;

    event AuthorizedMinterAdded(address indexed minter);
    event AuthorizedMinterRemoved(address indexed minter);

    error NotAuthorized();

    /**
     * @dev Modifier to check if the sender is an authorized minter
     */
    modifier onlyAuthorizedMinter() {
        if (!isAuthorizedMinter(msg.sender)) revert NotAuthorized();
        _;
    }

    /**
     * @dev Add an authorized minter. Implementation should include access control.
     * @param minter Address to be added as an authorized minter
     */
    function addAuthorizedMinter(address minter) external virtual;

    /**
     * @dev Remove an authorized minter. Implementation should include access control.
     * @param minter Address to be removed from authorized minters
     */
    function removeAuthorizedMinter(address minter) external virtual;

    /**
     * @dev Internal function to add an authorized minter
     * @param minter Address to be added as an authorized minter
     */
    function _addAuthorizedMinter(address minter) internal {
        _authorizedMinters[minter] = true;
        emit AuthorizedMinterAdded(minter);
    }

    /**
     * @dev Internal function to remove an authorized minter
     * @param minter Address to be removed from authorized minters
     */
    function _removeAuthorizedMinter(address minter) internal {
        _authorizedMinters[minter] = false;
        emit AuthorizedMinterRemoved(minter);
    }

    /**
     * @dev Check if an address is an authorized minter
     * @param minter Address to check
     * @return bool True if the address is an authorized minter, false otherwise
     */
    function isAuthorizedMinter(address minter) public view returns (bool) {
        return _authorizedMinters[minter];
    }
}
