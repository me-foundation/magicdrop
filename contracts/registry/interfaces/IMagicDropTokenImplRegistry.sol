// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenStandard} from "../../common/Structs.sol";

interface IMagicDropTokenImplRegistry {
    function registerImplementation(TokenStandard standard, address impl, bool isDefault) external returns (uint32);
    function unregisterImplementation(TokenStandard standard, uint32 implId) external;
    function getImplementation(TokenStandard standard, uint32 implId) external view returns (address);
}
