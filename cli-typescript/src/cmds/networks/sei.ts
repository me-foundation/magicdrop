import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../../utils/createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum SeiChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const seiChainIdsByName = new Map([
  [SeiChains.MAINNET, SUPPORTED_CHAINS.SEI],
]);

const seiPlatform = new EvmPlatform(
  'Sei',
  getSymbolFromChainId(SUPPORTED_CHAINS.SEI),
  seiChainIdsByName,
  SeiChains.MAINNET,
);

export const sei = createEvmCommand({
  platform: seiPlatform,
  commandAliases: ['s'],
});

export default sei;
