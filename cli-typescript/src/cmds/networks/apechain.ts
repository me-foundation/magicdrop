import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum Apechains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const apeChainIdsByName = new Map([
  [Apechains.MAINNET, SUPPORTED_CHAINS.APECHAIN],
]);

const apechainPlatform = new EvmPlatform(
  'ApeChain',
  getSymbolFromChainId(SUPPORTED_CHAINS.APECHAIN),
  apeChainIdsByName,
  Apechains.MAINNET,
);

export const apechain = createEvmCommand({
  platform: apechainPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.APECHAIN).toLowerCase(),
    'a',
  ],
});

export default apechain;
