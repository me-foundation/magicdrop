import { SUPPORTED_CHAINS } from '../utils/constants';
import { EvmPlatform } from '../utils/evmUtils';
import { createEvmCommand } from '../utils/createCommand';
import { getSymbolFromChainId } from '../utils/getters';

const ethPlatform = new EvmPlatform(
  'Ethereum',
  getSymbolFromChainId(SUPPORTED_CHAINS.ETHEREUM),
  [SUPPORTED_CHAINS.ETHEREUM, SUPPORTED_CHAINS.SEPOLIA],
  SUPPORTED_CHAINS.SEPOLIA,
);

export const eth = createEvmCommand({
  platform: ethPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.ETHEREUM).toLowerCase(),
    'e',
  ],
});

const polygonPlatform = new EvmPlatform(
  'Polygon',
  getSymbolFromChainId(SUPPORTED_CHAINS.POLYGON),
  [SUPPORTED_CHAINS.POLYGON, SUPPORTED_CHAINS.AVALANCHE],
  SUPPORTED_CHAINS.POLYGON,
);

export const polygon = createEvmCommand({
  platform: polygonPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.POLYGON).toLowerCase(),
    'p',
  ],
});

const bscPlatform = new EvmPlatform(
  'BSC',
  getSymbolFromChainId(SUPPORTED_CHAINS.BSC),
  [SUPPORTED_CHAINS.BSC],
  SUPPORTED_CHAINS.BSC,
);

export const bsc = createEvmCommand({
  platform: bscPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.BSC).toLowerCase(),
    'binance',
  ],
});

const arbitrumPlatform = new EvmPlatform(
  'Arbitrum',
  getSymbolFromChainId(SUPPORTED_CHAINS.ARBITRUM),
  [SUPPORTED_CHAINS.ARBITRUM],
  SUPPORTED_CHAINS.ARBITRUM,
);

export const arbitrum = createEvmCommand({
  platform: arbitrumPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.ARBITRUM).toLowerCase(),
  ],
});

const basePlatform = new EvmPlatform(
  'Base',
  getSymbolFromChainId(SUPPORTED_CHAINS.BASE),
  [SUPPORTED_CHAINS.BASE],
  SUPPORTED_CHAINS.BASE,
);

export const base = createEvmCommand({
  platform: basePlatform,
  commandAliases: ['b'],
});
const seiPlatform = new EvmPlatform(
  'Sei',
  getSymbolFromChainId(SUPPORTED_CHAINS.SEI),
  [SUPPORTED_CHAINS.SEI],
  SUPPORTED_CHAINS.SEI,
);

export const sei = createEvmCommand({
  platform: seiPlatform,
  commandAliases: ['s'],
});

const apechainPlatform = new EvmPlatform(
  'ApeChain',
  getSymbolFromChainId(SUPPORTED_CHAINS.APECHAIN),
  [SUPPORTED_CHAINS.APECHAIN],
  SUPPORTED_CHAINS.APECHAIN,
);

export const apechain = createEvmCommand({
  platform: apechainPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.APECHAIN).toLowerCase(),
    'a',
  ],
});

const abstractPlatform = new EvmPlatform(
  'Abstract',
  getSymbolFromChainId(SUPPORTED_CHAINS.ABSTRACT),
  [SUPPORTED_CHAINS.ABSTRACT],
  SUPPORTED_CHAINS.ABSTRACT,
);

export const abstract = createEvmCommand({
  platform: abstractPlatform,
  commandAliases: ['abs'],
});

const berachainPlatform = new EvmPlatform(
  'Berachain',
  getSymbolFromChainId(SUPPORTED_CHAINS.BERACHAIN),
  [SUPPORTED_CHAINS.BERACHAIN],
  SUPPORTED_CHAINS.BERACHAIN,
);

export const berachain = createEvmCommand({
  platform: berachainPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.BERACHAIN).toLowerCase(),
  ],
});

const monadPlatform = new EvmPlatform(
  'Monad',
  getSymbolFromChainId(SUPPORTED_CHAINS.MONAD_TESTNET),
  [SUPPORTED_CHAINS.MONAD_TESTNET],
  SUPPORTED_CHAINS.MONAD_TESTNET,
);

export const monad = createEvmCommand({
  platform: monadPlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.MONAD_TESTNET).toLowerCase(),
    'm',
  ],
});

const avalanchePlatform = new EvmPlatform(
  'Avalanche',
  getSymbolFromChainId(SUPPORTED_CHAINS.AVALANCHE),
  [SUPPORTED_CHAINS.AVALANCHE],
  SUPPORTED_CHAINS.AVALANCHE,
);

export const avalanche = createEvmCommand({
  platform: avalanchePlatform,
  commandAliases: [
    getSymbolFromChainId(SUPPORTED_CHAINS.AVALANCHE).toLowerCase(),
    'avx',
  ],
});
