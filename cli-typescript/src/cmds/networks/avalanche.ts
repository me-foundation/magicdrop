import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../../utils/createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum AvalancheChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const avalancheChainIdsByName = new Map([
  [AvalancheChains.MAINNET, SUPPORTED_CHAINS.AVALANCHE],
]);

const avalanchePlatform = new EvmPlatform(
  'Avalanche',
  getSymbolFromChainId(SUPPORTED_CHAINS.AVALANCHE),
  avalancheChainIdsByName,
  AvalancheChains.MAINNET,
);

export const avalanche = createEvmCommand({
  platform: avalanchePlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.AVALANCHE).toLowerCase(),
    'avx',
  ],
});

export default avalanche;
