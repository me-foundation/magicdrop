// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "contracts/creator-token-standards/interfaces/ITransferSecurityRegistry.sol";

interface ITransferSecurityRegistryV2 is ITransferSecurityRegistry {
    event CreatedList(uint256 indexed id, string name);
    event AppliedListToCollection(address indexed collection, uint120 indexed id);
    event ReassignedListOwnership(uint256 indexed id, address indexed newOwner);
    event AddedAccountToList(ListTypes indexed kind, uint256 indexed id, address indexed account);
    event AddedCodeHashToList(ListTypes indexed kind, uint256 indexed id, bytes32 indexed codehash);
    event RemovedAccountFromList(ListTypes indexed kind, uint256 indexed id, address indexed account);
    event RemovedCodeHashFromList(ListTypes indexed kind, uint256 indexed id, bytes32 indexed codehash);

    function transferSecurityPolicies(TransferSecurityLevels level) external pure returns (CallerConstraints callerConstraints, ReceiverConstraints receiverConstraints);
    function createList(string calldata name) external returns (uint120);
    function createListCopy(string calldata name, uint120 sourceListId) external returns (uint120);
    function reassignOwnershipOfList(uint120 id, address newOwner) external;
    function renounceOwnershipOfList(uint120 id) external;
    function applyListToCollection(address collection, uint120 id) external;
    function getCollectionSecurityPolicyV2(address collection) external view returns (CollectionSecurityPolicyV2 memory);
    function addAccountsToBlacklist(uint120 id, address[] calldata accounts) external;
    function addAccountsToWhitelist(uint120 id, address[] calldata accounts) external;
    function addCodeHashesToBlacklist(uint120 id, bytes32[] calldata codehashes) external;
    function addCodeHashesToWhitelist(uint120 id, bytes32[] calldata codehashes) external;
    function removeAccountsFromBlacklist(uint120 id, address[] calldata accounts) external;
    function removeAccountsFromWhitelist(uint120 id, address[] calldata accounts) external;
    function removeCodeHashesFromBlacklist(uint120 id, bytes32[] calldata codehashes) external;
    function removeCodeHashesFromWhitelist(uint120 id, bytes32[] calldata codehashes) external;
    function getBlacklistedAccounts(uint120 id) external view returns (address[] memory);
    function getWhitelistedAccounts(uint120 id) external view returns (address[] memory);
    function getBlacklistedCodeHashes(uint120 id) external view returns (bytes32[] memory);
    function getWhitelistedCodeHashes(uint120 id) external view returns (bytes32[] memory);
    function isAccountBlacklisted(uint120 id, address account) external view returns (bool);
    function isAccountWhitelisted(uint120 id, address account) external view returns (bool);
    function isCodeHashBlacklisted(uint120 id, bytes32 codehash) external view returns (bool);
    function isCodeHashWhitelisted(uint120 id, bytes32 codehash) external view returns (bool);
    function getBlacklistedAccountsByCollection(address collection) external view returns (address[] memory);
    function getWhitelistedAccountsByCollection(address collection) external view returns (address[] memory);
    function getBlacklistedCodeHashesByCollection(address collection) external view returns (bytes32[] memory);
    function getWhitelistedCodeHashesByCollection(address collection) external view returns (bytes32[] memory);
    function isAccountBlacklistedByCollection(address collection, address account) external view returns (bool);
    function isAccountWhitelistedByCollection(address collection, address account) external view returns (bool);
    function isCodeHashBlacklistedByCollection(address collection, bytes32 codehash) external view returns (bool);
    function isCodeHashWhitelistedByCollection(address collection, bytes32 codehash) external view returns (bool);
}