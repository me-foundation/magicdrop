import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum AbstractChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const abstractChainIdsByName = new Map([
  [AbstractChains.MAINNET, SUPPORTED_CHAINS.ABSTRACT],
]);

const abstractPlatform = new EvmPlatform(
  'Abstract',
  getSymbolFromChainId(SUPPORTED_CHAINS.ABSTRACT),
  abstractChainIdsByName,
  AbstractChains.MAINNET,
);

export const abstract = createEvmCommand({
  platform: abstractPlatform,
  commandAliases: ['abs'],
});

export default abstract;
