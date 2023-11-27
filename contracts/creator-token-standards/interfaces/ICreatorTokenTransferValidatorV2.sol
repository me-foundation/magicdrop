// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/creator-token-standards/interfaces/IEOARegistry.sol";
import "contracts/creator-token-standards/interfaces/ITransferSecurityRegistryV2.sol";
import "contracts/creator-token-standards/interfaces/ITransferValidator.sol";

interface ICreatorTokenTransferValidatorV2 is ITransferSecurityRegistryV2, ITransferValidator, IEOARegistry {}