import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../../utils/createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum ArbitrumChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const arbitrumChainIdsByName = new Map([
  [ArbitrumChains.MAINNET, SUPPORTED_CHAINS.ARBITRUM],
]);

const arbitrumPlatform = new EvmPlatform(
  'Arbitrum',
  getSymbolFromChainId(SUPPORTED_CHAINS.ARBITRUM),
  arbitrumChainIdsByName,
  ArbitrumChains.MAINNET,
);

export const arbitrum = createEvmCommand({
  platform: arbitrumPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.ARBITRUM).toLowerCase(),
  ],
});

export default arbitrum;
