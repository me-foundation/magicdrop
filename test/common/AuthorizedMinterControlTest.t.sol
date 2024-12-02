// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {AuthorizedMinterControl} from "../../contracts/common/AuthorizedMinterControl.sol";

contract MockAuthorizedMinterControl is AuthorizedMinterControl {
    event Minted(address to, uint256 amount);

    function addAuthorizedMinter(address minter) public override {
        _addAuthorizedMinter(minter);
    }

    function removeAuthorizedMinter(address minter) public override {
        _removeAuthorizedMinter(minter);
    }

    function mint(address to, uint256 amount) public onlyAuthorizedMinter {
        emit Minted(to, amount);
    }
}

contract AuthorizedMinterControlTest is Test {
    MockAuthorizedMinterControl public authorizedMinterControl;

    function setUp() public {
        authorizedMinterControl = new MockAuthorizedMinterControl();
    }

    function test_addAuthorizedMinter() public {
        authorizedMinterControl.addAuthorizedMinter(address(1));
        assertTrue(authorizedMinterControl.isAuthorizedMinter(address(1)));
    }

    function test_removeAuthorizedMinter() public {
        authorizedMinterControl.addAuthorizedMinter(address(1));
        authorizedMinterControl.removeAuthorizedMinter(address(1));
        assertFalse(authorizedMinterControl.isAuthorizedMinter(address(1)));
    }

    function test_isAuthorizedMinter() public {
        assertFalse(authorizedMinterControl.isAuthorizedMinter(address(1)));
    }

    function test_mint() public {
        authorizedMinterControl.addAuthorizedMinter(address(1));
        vm.prank(address(1));
        authorizedMinterControl.mint(address(2), 1);
        assertTrue(authorizedMinterControl.isAuthorizedMinter(address(1)));
    }

    function test_mint_unauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(AuthorizedMinterControl.NotAuthorized.selector));
        authorizedMinterControl.mint(address(2), 1);
    }
}
