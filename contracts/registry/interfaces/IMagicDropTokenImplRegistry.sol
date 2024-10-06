// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenStandard} from "../../common/Structs.sol";

interface IMagicDropTokenImplRegistry {
    function registerImplementation(TokenStandard standard, address impl) external returns (uint32);
    function deprecateImplementation(TokenStandard standard, uint32 implId) external;
    function getImplementation(TokenStandard standard, uint32 implId) external view returns (address, bool);
}
