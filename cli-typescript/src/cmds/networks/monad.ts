import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum MonadChains {
  TESTNET = 'testnet',
}

// Chain ids by the chain names
export const monadChainIdsByName = new Map([
  [MonadChains.TESTNET, SUPPORTED_CHAINS.MONAD_TESTNET],
]);

const monadPlatform = new EvmPlatform(
  'Monad',
  getSymbolFromChainId(SUPPORTED_CHAINS.MONAD_TESTNET),
  monadChainIdsByName,
  MonadChains.TESTNET,
);

export const monad = createEvmCommand({
  platform: monadPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.MONAD_TESTNET).toLowerCase(),
    'm',
  ],
});

export default monad;
