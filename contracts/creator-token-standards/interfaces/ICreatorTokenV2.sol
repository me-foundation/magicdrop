// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/creator-token-standards/interfaces/ICreatorTokenTransferValidatorV2.sol";
import "contracts/creator-token-standards/interfaces/ICreatorToken.sol";

interface ICreatorTokenV2 is ICreatorToken {
    function getTransferValidatorV2() external view returns (ICreatorTokenTransferValidatorV2);
    function getSecurityPolicyV2() external view returns (CollectionSecurityPolicyV2 memory);
    function getBlacklistedAccounts() external view returns (address[] memory);
    function getWhitelistedAccounts() external view returns (address[] memory);
    function getBlacklistedCodeHashes() external view returns (bytes32[] memory);
    function getWhitelistedCodeHashes() external view returns (bytes32[] memory);
    function isAccountBlacklisted(address account) external view returns (bool);
    function isAccountWhitelisted(address account) external view returns (bool);
    function isCodeHashBlacklisted(bytes32 codehash) external view returns (bool);
    function isCodeHashWhitelisted(bytes32 codehash) external view returns (bool);
}
