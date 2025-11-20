import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum MonadChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const monadChainIdsByName = new Map([
  [MonadChains.MAINNET, SUPPORTED_CHAINS.MONAD],
]);

const monadPlatform = new EvmPlatform(
  'Monad',
  getSymbolFromChainId(SUPPORTED_CHAINS.MONAD),
  monadChainIdsByName,
  MonadChains.MAINNET,
);

export const monad = createEvmCommand({
  platform: monadPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.MONAD).toLowerCase(),
    'm',
  ],
});

export default monad;
