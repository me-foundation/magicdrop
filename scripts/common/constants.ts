// This module wraps up the constants which can be used by any script

export const ContractDetails = {
  ERC721CM: { name: 'ERC721CM' }, // ERC721M on ERC721C v2
  ERC721M: { name: 'ERC721M' }, // The contract of direct sales
  ERC721MOperatorFilterer: { name: 'ERC721MOperatorFilterer' }, // ERC721M with operator filterer
  BucketAuction: { name: 'BucketAuction' }, // The contract of bucket auctions
  ERC1155M: { name: 'ERC1155M' }, // ERC1155M
} as const;

export const ERC721BatchTransferContract =
  '0x38F7ba911f7efc434D29D6E39c814E9d4De3FEef';

export const ERC721CV2_VALIDATOR = '0x721C00182a990771244d7A71B9FA2ea789A3b433';
export const ERC721CV2_FREEZE_LEVEL = 4;
export const ERC721CV2_EMPTY_LIST = 4;

export const RESERVOIR_RELAYER_MUTLICALLER = '0xb90ed4c123843cbFD66b11411Ee7694eF37E6E72';
export const RESERVOIR_RELAYER_ROUTER = '0x2f5d6b76bf8086797e1bd0b28bb4dd5583476cc9';
