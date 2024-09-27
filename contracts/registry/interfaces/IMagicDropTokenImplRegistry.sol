// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenStandard} from "../../common/Structs.sol";

interface IMagicDropTokenImplRegistry {
    event ImplementationRegistered(TokenStandard standard, address impl, uint256 implId);
    event ImplementationUnregistered(TokenStandard standard, uint256 implId);

    error ImplementationNotRegistered();

    function registerImplementation(TokenStandard standard, address impl) external returns (uint256);
    function unregisterImplementation(TokenStandard standard, uint256 implId) external;
    function getImplementation(TokenStandard standard, uint256 implId) external view returns (address);
}
