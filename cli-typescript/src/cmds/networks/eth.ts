import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum EthChains {
  MAINNET = 'mainnet',
  SEPOLIA = 'sepolia',
}

// Chain ids by the chain names
export const ethChainIdsByName = new Map([
  [EthChains.MAINNET, SUPPORTED_CHAINS.ETHEREUM],
  [EthChains.SEPOLIA, SUPPORTED_CHAINS.SEPOLIA],
]);

const ethPlatform = new EvmPlatform(
  'Ethereum',
  getSymbolFromChainId(SUPPORTED_CHAINS.ETHEREUM),
  ethChainIdsByName,
  EthChains.SEPOLIA,
);

export const eth = createEvmCommand({
  platform: ethPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.ETHEREUM).toLowerCase(),
    'e',
  ],
});

export default eth;
