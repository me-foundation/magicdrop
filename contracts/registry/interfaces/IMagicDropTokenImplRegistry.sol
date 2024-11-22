// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {TokenStandard} from "../../common/Structs.sol";

interface IMagicDropTokenImplRegistry {
    function registerImplementation(TokenStandard standard, address impl, bool isDefault, uint256 deploymentFee)
        external
        returns (uint32);
    function unregisterImplementation(TokenStandard standard, uint32 implId) external;
    function getImplementation(TokenStandard standard, uint32 implId) external view returns (address);
    function getDeploymentFee(TokenStandard standard, uint32 implId) external view returns (uint256);
    function setDeploymentFee(TokenStandard standard, uint32 implId, uint256 deploymentFee) external;
}
