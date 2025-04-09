import { SUPPORTED_CHAINS } from '../../utils/constants';
import { EvmPlatform } from '../../utils/evmUtils';
import { createEvmCommand } from '../createCommand';

const platform = new EvmPlatform(
  'Ethereum',
  'eth',
  [SUPPORTED_CHAINS.ETHEREUM, SUPPORTED_CHAINS.SEPOLIA],
  SUPPORTED_CHAINS.SEPOLIA,
);

// Create the command
const eth = createEvmCommand({
  platform,
  commandAliases: ['eth', 'e'],
});

export default eth;