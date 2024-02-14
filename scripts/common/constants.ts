// This module wraps up the constants which can be used by any script

export const ContractDetails = {
  ERC721CM: { name: 'ERC721CM' }, // ERC721M on ERC721C v2
  ERC721CMBasicRoyalties: { name: 'ERC721CMBasicRoyalties' }, // ERC721M on ERC721C v2 with basic royalties
  ERC721M: { name: 'ERC721M' }, // The contract of direct sales
  ERC721MIncreasableSupply: { name: 'ERC721MIncreasableSupply' }, // ERC721M with increasable supply
  ERC721MOperatorFilterer: { name: 'ERC721MOperatorFilterer' }, // ERC721M with operator filterer
  ERC721MIncreasableOperatorFilterer: {
    name: 'ERC721MIncreasableOperatorFilterer',
  }, // ERC721M with increasable supply and operator filterer
  ERC721MAutoApprover: { name: 'ERC721MAutoApprover' }, // ERC721M with auto approver
  ERC721MOperatorFiltererAutoApprover: {
    name: 'ERC721MOperatorFiltererAutoApprover',
  }, // ERC721M with operator filterer and auto approver
  ERC721MPausable: { name: 'ERC721MPausable' }, // ERC721M with Pausable
  ERC721MPausableOperatorFilterer: { name: 'ERC721MPausableOperatorFilterer' }, // ERC721M with Pausable and operator filterer
  ERC721MOnft: { name: 'ERC721MOnft' }, // ERC721M with LayerZero integration
  ONFT721Lite: { name: 'ONFT721Lite' }, // ERC721 non-minting with LayerZero integration
  BucketAuction: { name: 'BucketAuction' }, // The contract of bucket auctions
  BucketAuctionOperatorFilterer: { name: 'BucketAuctionOperatorFilterer' }, // Bucket auction with operator filterer
} as const;

export const LayerZeroEndpoints: Record<string, string> = {
  ethereum: '0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675',
  bsc: '0x3c2269811836af69497E5F486A85D7316753cf62',
  avalanche: '0x3c2269811836af69497E5F486A85D7316753cf62',
  polygon: '0x3c2269811836af69497E5F486A85D7316753cf62',
  arbitrum: '0x3c2269811836af69497E5F486A85D7316753cf62',
  optimism: '0x3c2269811836af69497E5F486A85D7316753cf62',
  fantom: '0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7',
  goerli: '0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23',
  'bsc-testnet': '0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1',
  fuji: '0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706',
  mumbai: '0xf69186dfBa60DdB133E91E9A4B5673624293d8F8',
  'arbitrum-goerli': '0x6aB5Ae6822647046626e83ee6dB8187151E1d5ab',
  'optimism-goerli': '0xae92d5aD7583AD66E49A0c67BAd18F6ba52dDDc1',
  'fantom-testnet': '0x7dcAD72640F835B0FA36EFD3D6d3ec902C7E5acf',
  'meter-testnet': '0x3De2f3D1Ac59F18159ebCB422322Cb209BA96aAD',
  'zksync-testnet': '0x093D2CF57f764f09C3c2Ac58a42A2601B8C79281',
} as const;

export const ChainIds: Record<string, number> = {
  ethereum: 101,
  bsc: 102,
  avalanche: 106,
  polygon: 109,
  arbitrum: 110,
  optimism: 111,
  fantom: 112,

  goerli: 10121,
  'bsc-testnet': 10102,
  fuji: 10106,
  mumbai: 10109,
  'arbitrum-goerli': 10143,
  'optimism-goerli': 10132,
  'fantom-testnet': 10112,
  'meter-testnet': 10156,
  'zksync-testnet': 10165,
};

export const ERC721BatchTransferContract = '0x9754f8cf81A8efA9BC5686BddbadA174E43b8aeb';