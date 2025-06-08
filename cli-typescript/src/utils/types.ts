import { Hex } from 'viem';
import { SUPPORTED_CHAINS, TOKEN_STANDARD } from './constants';
import { ContractManager } from './ContractManager';
import { getProjectStore } from './fileUtils';

export interface ERC721Stage {
  price: string;
  mintFee: string;
  walletLimit: number;
  maxStageSupply?: number;
  startTime: string;
  endTime: string;
}

export interface Deployment {
  contract_address: string;
  initial_owner: string;
  deployed_at: string;
}

export interface ERC721Collection {
  name: string;
  symbol: string;
  chainId: SUPPORTED_CHAINS;
  tokenStandard: TOKEN_STANDARD.ERC721;
  maxMintableSupply: number;
  globalWalletLimit: number;
  mintCurrency: string;
  fundReceiver: string;
  royaltyReceiver: string;
  royaltyFee: number;
  mintable: boolean;
  cosigner: string;
  tokenUriSuffix: string;
  uri: string;
  useERC721C: boolean;
  stages: ERC721Stage[];
  deployment?: Deployment;
}

export interface ERC1155Stage {
  price: string[];
  mintFee: string[];
  walletLimit: number[];
  maxStageSupply?: number[];
  startTime: string;
  endTime: string;
}

export interface ERC1155Collection {
  name: string;
  symbol: string;
  chainId: SUPPORTED_CHAINS;
  tokenStandard: TOKEN_STANDARD.ERC1155;
  maxMintableSupply: number[];
  globalWalletLimit: number[];
  mintCurrency: string;
  fundReceiver: string;
  royaltyReceiver: string;
  royaltyFee: number;
  mintable: boolean;
  cosigner: string;
  uri: string;
  stages: ERC1155Stage[];
  deployment?: Deployment;
}

export type Collection = ERC721Collection | ERC1155Collection;

export type DeployContractConfig = Collection & {
  store: ReturnType<typeof getProjectStore>;
  setupContractOption?: 'yes' | 'no' | 'deferred';
  tokenUriSuffix?: string;
  contractManager: ContractManager;
  totalTokens?: number;
  stagesFile?: string;
};

export interface Log {
  address: string;
  topics: string[];
  data: string;
  blockHash: string;
  blockNumber: string;
  blockTimestamp: string;
  transactionHash: string;
  transactionIndex: string;
  logIndex: string;
  removed: boolean;
}

export interface TransactionData {
  status: string;
  cumulativeGasUsed: string;
  logs: Log[];
  logsBloom: string;
  type: string;
  transactionHash: string;
  transactionIndex: string;
  blockHash: string;
  blockNumber: string;
  gasUsed: string;
  effectiveGasPrice: string;
  from: string;
  to: string;
  contractAddress: string | null;
}

export type ERC721StageData = {
  price: string;
  mintFee: string;
  walletLimit: number;
  merkleRoot: string;
  maxStageSupply: number;
  startTime: number;
  endTime: number;
};

export type ERC1155StageData = {
  price: string[];
  mintFee: string[];
  walletLimit: number[];
  merkleRoot: Hex[];
  maxStageSupply: number[];
  startTime: number;
  endTime: number;
};
