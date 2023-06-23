// This module wraps up the constants which can be used by any script

export const ContractDetails = {
  ERC721M: { name: 'ERC721M' }, // The contract of direct sales
  ERC721MIncreasableSupply: { name: 'ERC721MIncreasableSupply' }, // ERC721M with increasable supply
  ERC721MOperatorFilterer: { name: 'ERC721MOperatorFilterer' }, // ERC721M with operator filterer
  ERC721MIncreasableOperatorFilterer: { name: 'ERC721MIncreasableOperatorFilterer' }, // ERC721M with increasable supply and operator filterer
  ERC721MAutoApprover: { name: 'ERC721MAutoApprover' }, // ERC721M with auto approver
  ERC721MOperatorFiltererAutoApprover: { name: 'ERC721MOperatorFiltererAutoApprover' }, // ERC721M with operator filterer and auto approver
  BucketAuction: { name: 'BucketAuction' }, // The contract of bucket auctions
  BucketAuctionOperatorFilterer: { name: 'BucketAuctionOperatorFilterer' }, // Bucket auction with operator filterer
} as const;
