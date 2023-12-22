// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(uint256 initialSupply) ERC20("Mock", "MOCK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
