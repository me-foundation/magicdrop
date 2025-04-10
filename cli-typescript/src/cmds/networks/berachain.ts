import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../../utils/createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum Berachains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const beraChainIdsByName = new Map([
  [Berachains.MAINNET, SUPPORTED_CHAINS.BERACHAIN],
]);

const beraPlatform = new EvmPlatform(
  'Berachain',
  getSymbolFromChainId(SUPPORTED_CHAINS.BERACHAIN),
  beraChainIdsByName,
  Berachains.MAINNET,
);

export const berachain = createEvmCommand({
  platform: beraPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.BERACHAIN).toLowerCase(),
  ],
});

export default berachain;
