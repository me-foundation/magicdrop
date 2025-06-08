import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum BaseChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const baseChainIdsByName = new Map([
  [BaseChains.MAINNET, SUPPORTED_CHAINS.BASE],
]);

const basePlatform = new EvmPlatform(
  'Base',
  getSymbolFromChainId(SUPPORTED_CHAINS.BASE),
  baseChainIdsByName,
  BaseChains.MAINNET,
);

export const base = createEvmCommand({
  platform: basePlatform,
  commandAliases: ['b'],
});

export default base;
