// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IInitializableToken} from "../common/interfaces/IInitializableToken.sol";

contract MagicDropERC721Initializable is ERC721Upgradeable, OwnableUpgradeable, IInitializableToken {
    string private baseURI = "";

    function initialize(string memory name, string memory symbol, address payable initialOwner)
        external
        override
        initializer
    {
        __ERC721_init(name, symbol);
        __Ownable_init(initialOwner);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _mint(to, tokenId);
    }
}
