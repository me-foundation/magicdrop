// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IInitializableToken} from "../common/interfaces/IInitializableToken.sol";

contract MagicDropERC1155Initializable is ERC1155Upgradeable, OwnableUpgradeable, IInitializableToken {
    string private _name;
    string private _symbol;

    function initialize(
        string calldata name_,
        string calldata symbol_,
        address payable initialOwner
    ) external initializer override {
        _name = name_;
        _symbol = symbol_;
        __ERC1155_init("");
        __Ownable_init(initialOwner);
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function setURI(string calldata newuri) external onlyOwner {
        _setURI(newuri);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        _mint(to, id, amount, data);
    }
}
