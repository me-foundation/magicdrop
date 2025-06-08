import { SUPPORTED_CHAINS } from '../../utils/constants';
import { createEvmCommand } from '../createCommand';
import { EvmPlatform } from '../../utils/evmUtils';
import { getSymbolFromChainId } from '../../utils/getters';

// Supported chain names
export enum PolygonChains {
  MAINNET = 'mainnet',
}

// Chain ids by the chain names
export const polygonChainIdsByName = new Map([
  [PolygonChains.MAINNET, SUPPORTED_CHAINS.POLYGON],
]);

const polygonPlatform = new EvmPlatform(
  'Polygon',
  getSymbolFromChainId(SUPPORTED_CHAINS.POLYGON),
  polygonChainIdsByName,
  PolygonChains.MAINNET,
);

export const polygon = createEvmCommand({
  platform: polygonPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.POLYGON).toLowerCase(),
    'p',
  ],
});

export default polygon;
