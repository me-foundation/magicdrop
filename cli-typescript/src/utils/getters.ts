import { confirm } from '@inquirer/prompts';
import {
  ABSTRACT_FACTORY_ADDRESS,
  ABSTRACT_REGISTRY_ADDRESS,
  AVALANCHE_FACTORY_ADDRESS,
  AVALANCHE_REGISTRY_ADDRESS,
  DEFAULT_COLLECTION_DIR,
  DEFAULT_FACTORY_ADDRESS,
  DEFAULT_IMPL_ID,
  DEFAULT_LIST_ID,
  DEFAULT_REGISTRY_ADDRESS,
  explorerUrls,
  LIMIT_BREAK_TRANSFER_VALIDATOR_V5,
  SUPPORTED_CHAINS,
  supportedChainNames,
  TOKEN_STANDARD,
} from './constants';
import { TransactionData } from './types';
import {
  abstract,
  apeChain,
  arbitrum,
  avalanche,
  base,
  berachain,
  bsc,
  mainnet,
  monadTestnet,
  polygon,
  sei,
  sepolia,
} from 'viem/chains';
import { Hex } from 'viem';
import { setBaseDir } from './setters';

/**
 * Retrieves the transfer validator address
 * @returns The transfer validator address
 */
export const getTransferValidatorAddress = (): Hex => {
  // Limit Break CreatorTokenTransferValidator is deployed to the same
  // Address on all of our mainnet production EVM chains
  return LIMIT_BREAK_TRANSFER_VALIDATOR_V5;
};

export const getZksyncFlag = (chainId: SUPPORTED_CHAINS): string => {
  if (chainId === SUPPORTED_CHAINS.ABSTRACT) return '--zksync';

  return '';
};

export const getSymbolFromChainId = (chainId: SUPPORTED_CHAINS): string => {
  switch (chainId) {
    case SUPPORTED_CHAINS.ETHEREUM:
      return 'ETH';
    case SUPPORTED_CHAINS.POLYGON:
      return 'MATIC';
    case SUPPORTED_CHAINS.BSC:
      return 'BNB';
    case SUPPORTED_CHAINS.BASE:
      return 'BASE';
    case SUPPORTED_CHAINS.SEI:
      return 'SEI';
    case SUPPORTED_CHAINS.APECHAIN:
      return 'APE';
    case SUPPORTED_CHAINS.BERACHAIN:
      return 'BERA';
    case SUPPORTED_CHAINS.SEPOLIA:
      return 'SEP';
    case SUPPORTED_CHAINS.ARBITRUM:
      return 'ARB';
    case SUPPORTED_CHAINS.ABSTRACT:
      return 'ETH';
    case SUPPORTED_CHAINS.MONAD_TESTNET:
      return 'MON';
    case SUPPORTED_CHAINS.AVALANCHE:
      return 'AVAX';
    default:
      return 'Unknown';
  }
};

/**
 * Retrieves the chain ID based on the chain name.
 * @param chainName The name of the chain (e.g., "ethereum", "polygon").
 * @returns The chain ID corresponding to the given chain name.
 * @throws Error if the chain name is not found in the supported chains.
 */
export const getChainIdFromName = (chainName: string): SUPPORTED_CHAINS => {
  const chain = Object.entries(supportedChainNames).find(
    ([_, value]) => value.toLowerCase() === chainName.toLowerCase(),
  );

  if (chain) {
    return Number(chain[0]) as SUPPORTED_CHAINS;
  } else {
    throw new Error(`Chain name "${chainName}" not found.`);
  }
};

/**
 * Maps SUPPORTED_CHAINS to viem chains.
 * @param chainId The chain ID of the network.
 * @returns The viem chain object corresponding to the chain ID.
 * @throws Error if the chain ID is not supported.
 */
export const getViemChainByChainId = (chainId: SUPPORTED_CHAINS) => {
  switch (chainId) {
    case SUPPORTED_CHAINS.ETHEREUM:
      return mainnet;
    case SUPPORTED_CHAINS.POLYGON:
      return polygon;
    case SUPPORTED_CHAINS.BSC:
      return bsc;
    case SUPPORTED_CHAINS.ARBITRUM:
      return arbitrum;
    case SUPPORTED_CHAINS.AVALANCHE:
      return avalanche;
    case SUPPORTED_CHAINS.BASE:
      return base;
    case SUPPORTED_CHAINS.SEI:
      return sei;
    case SUPPORTED_CHAINS.APECHAIN:
      return apeChain;
    case SUPPORTED_CHAINS.BERACHAIN:
      return berachain;
    case SUPPORTED_CHAINS.SEPOLIA:
      return sepolia;
    case SUPPORTED_CHAINS.ARBITRUM:
      return arbitrum;
    case SUPPORTED_CHAINS.ABSTRACT:
      return abstract;
    case SUPPORTED_CHAINS.MONAD_TESTNET:
      return monadTestnet;
    case SUPPORTED_CHAINS.AVALANCHE:
      return avalanche;
    default:
      throw new Error(`Unsupported chain ID: ${chainId}`);
  }
};

/**
 * Retrieves the transfer validator list ID
 * @returns The transfer validator list ID
 */
export const getTransferValidatorListId = (): number => {
  // The standard Limit Break owned list is 0
  // This should support SeaPort (and thus Magic Eden) by default
  return DEFAULT_LIST_ID;
};

/**
 * Returns the contract URL for a blockchain explorer based on the chain ID and contract address.
 * @param chainId The chain ID of the network.
 * @param contractAddress The contract address.
 * @returns The contract URL.
 * @throws Error if the chain ID is unsupported.
 */
export const getExplorerContractUrl = (
  chainId: SUPPORTED_CHAINS,
  contractAddress: string,
): string => {
  const explorerUrl = explorerUrls[chainId as SUPPORTED_CHAINS];

  if (!explorerUrl) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }

  return `${explorerUrl}/address/${contractAddress}`;
};

/**
 * Extracts the contract address from deployment logs based on the event signature.
 * @param txnData The transaction data.
 * @param eventSig The event signature to match.
 * @returns The extracted contract address (without the `0x` prefix) or `null` if not found.
 */
export const getContractAddressFromLogs = (
  txnData: TransactionData,
  eventSig: string,
): string | null => {
  try {
    for (const log of txnData.logs) {
      const topic0 = log.topics[0];
      if (topic0 === eventSig) {
        return log.data.replace(/^0x/, ''); // Remove the `0x` prefix from the data
      }
    }

    return null; // Return null if no matching log is found
  } catch (error: any) {
    console.error('Error parsing deployment data:', error.message);
    throw new Error('Failed to extract contract address from logs.');
  }
};

export const getFactoryAddress = (chainId: SUPPORTED_CHAINS): `0x${string}` => {
  if (chainId === SUPPORTED_CHAINS.ABSTRACT) {
    return ABSTRACT_FACTORY_ADDRESS;
  }

  if (chainId === SUPPORTED_CHAINS.AVALANCHE) {
    return AVALANCHE_FACTORY_ADDRESS;
  }

  return DEFAULT_FACTORY_ADDRESS;
};

export const getRegistryAddress = (
  chainId: SUPPORTED_CHAINS,
): `0x${string}` => {
  if (chainId === SUPPORTED_CHAINS.ABSTRACT) {
    return ABSTRACT_REGISTRY_ADDRESS;
  }

  if (chainId === SUPPORTED_CHAINS.AVALANCHE) {
    return AVALANCHE_REGISTRY_ADDRESS;
  }

  return DEFAULT_REGISTRY_ADDRESS;
};

/**
 * The latest MagicDrop v1.0.1 implementation ID for each supported chain.
 * @param chainId The chain ID to check the balance on.
 * @param tokenStandard ERC721 or ERC1155
 * @param useERC721C use ERC721C
 * @returns implementation ID
 */
export const getImplId = (
  chainId: SUPPORTED_CHAINS,
  tokenStandard: TOKEN_STANDARD,
  useERC721C?: boolean,
): number => {
  if (tokenStandard !== TOKEN_STANDARD.ERC721 || !useERC721C) {
    return DEFAULT_IMPL_ID;
  }

  switch (chainId) {
    case SUPPORTED_CHAINS.ABSTRACT:
      return 7; // ERC721C implementation ID / abstract
    case SUPPORTED_CHAINS.BASE:
      return 11;
    case SUPPORTED_CHAINS.ETHEREUM:
      return 10;
    case SUPPORTED_CHAINS.BERACHAIN:
      return 5;
    case SUPPORTED_CHAINS.MONAD_TESTNET:
      return 5;
    case SUPPORTED_CHAINS.AVALANCHE:
      return 6;
    default:
      return 8;
  }
};

export const getStandardId = (tokenStandard: TOKEN_STANDARD): string => {
  switch (tokenStandard) {
    case TOKEN_STANDARD.ERC721:
      return '0';
    case TOKEN_STANDARD.ERC1155:
      return '1';
    default:
      throw new Error(`Unsupported token standard: ${tokenStandard}`);
  }
};

export const promptForConfirmation = async (
  message?: string,
  defaultValue?: boolean,
): Promise<boolean> => {
  return confirm({
    message: message ?? 'Please confirm',
    default: defaultValue ?? true,
  });
};

/**
 * Returns the transaction URL for a blockchain explorer based on the chain ID and transaction hash.
 * @param chainId The chain ID of the network.
 * @param txHash The transaction hash.
 * @returns The transaction URL.
 * @throws Error if the chain ID is unsupported.
 */
export const getExplorerTxUrl = (
  chainId: SUPPORTED_CHAINS,
  txHash: string,
): string => {
  const explorerUrl = explorerUrls[chainId as SUPPORTED_CHAINS];

  if (!explorerUrl) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }

  return `${explorerUrl}/tx/${txHash}`;
};

export const getBaseDir = (): string => {
  const baseDir = process.env.BASE_DIR || setBaseDir();
  return baseDir;
};

export const getCollectionDir = (): string => {
  return process.env.MAGIC_DROP_COLLECTION_DIR || DEFAULT_COLLECTION_DIR;
};
