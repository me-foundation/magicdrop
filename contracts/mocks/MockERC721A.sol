// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import {ERC721A} from "erc721a/contracts/ERC721A.sol";

contract MockERC721A is ERC721A {
    // solhint-disable-next-line no-empty-blocks
    constructor() ERC721A("MOCK", "M") {}

    function mint(address to) external {
        _mint(to, 1);
    }

    function mintBatch(address to, uint256 quantity) external {
        _mint(to, quantity);
    }
}
