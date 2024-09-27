// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TokenStandard} from "../../common/Structs.sol";

interface IMagicDropCloneFactory {
    error ConstructorRegistryAddressCannotBeZero();

    event MagicDropFactoryInitialized();
    event NewContractInitialized(
        string name,
        string symbol,
        address indexed contractAddress,
        address indexed initialOwner,
        uint256 implId,
        TokenStandard standard
    );

    function createContract(
        string calldata name,
        string calldata symbol,
        TokenStandard standard,
        address payable initialOwner,
        uint256 implId,
        bytes32 salt
    ) external returns (address);
}
