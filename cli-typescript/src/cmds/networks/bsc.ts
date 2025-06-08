import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum bscChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const bscChainIdsByName = new Map([
  [bscChains.MAINNET, SUPPORTED_CHAINS.BSC],
]);

const bscPlatform = new EvmPlatform(
  'BSC',
  getSymbolFromChainId(SUPPORTED_CHAINS.BSC),
  bscChainIdsByName,
  bscChains.MAINNET,
);

export const bsc = createEvmCommand({
  platform: bscPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.BSC).toLowerCase(),
    'binance',
  ],
});

export default bsc;
