// This module wraps up the utility functions which can be used by any script

export const SaleTypes = {
  ERC721M: { enumVal: 0, strVal: 'ERC721M' }, // The contract of direct sales
  BucketAuction: { enumVal: 1, strVal: 'BucketAuction' }, // The contract of bucket auctions
};

export const StageTypes = {
  Public: { enumVal: 0, strVal: 'Public' }, // Stage where any wallet can buy
  WhiteList: { enumVal: 1, strVal: 'WhiteList' }, // Stage where only predetermined wallets can buy
};
