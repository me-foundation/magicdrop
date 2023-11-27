// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

enum ListTypes {
    Blacklist,
    Whitelist
}

enum AllowlistTypes {
    Operators,
    PermittedContractReceivers
}

enum ReceiverConstraints {
    None,
    NoCode,
    EOA
}

enum CallerConstraints {
    None,
    OperatorBlacklistEnableOTC,
    OperatorWhitelistEnableOTC,
    OperatorWhitelistDisableOTC
}

enum StakerConstraints {
    None,
    CallerIsTxOrigin,
    EOA
}

enum TransferSecurityLevels {
    Recommended,
    Zero,
    One,
    Two,
    Three,
    Four,
    Five,
    Six,
    Seven
}

struct TransferSecurityPolicy {
    CallerConstraints callerConstraints;
    ReceiverConstraints receiverConstraints;
}

struct CollectionSecurityPolicy {
    TransferSecurityLevels transferSecurityLevel;
    uint120 operatorWhitelistId;
    uint120 permittedContractReceiversId;
}

struct CollectionSecurityPolicyV2 {
    TransferSecurityLevels transferSecurityLevel;
    uint120 listId;
}

struct TransferValidatorReference {
    bool isInitialized;
    uint16 version;
    address transferValidator;
}