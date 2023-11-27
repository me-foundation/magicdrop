// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/creator-token-standards/interfaces/IEOARegistry.sol";
import "contracts/creator-token-standards/interfaces/ITransferSecurityRegistry.sol";
import "contracts/creator-token-standards/interfaces/ITransferValidator.sol";

interface ICreatorTokenTransferValidator is ITransferSecurityRegistry, ITransferValidator, IEOARegistry {}