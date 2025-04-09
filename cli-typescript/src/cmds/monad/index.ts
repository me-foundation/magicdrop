import { SUPPORTED_CHAINS } from '../../utils/constants';
import { EvmPlatform } from '../../utils/evmUtils';
import { createEvmCommand } from '../createCommand';

const platform = new EvmPlatform(
  'Monad',
  'mon',
  [SUPPORTED_CHAINS.MONAD_TESTNET],
  SUPPORTED_CHAINS.MONAD_TESTNET,
);

// Create the command
const monad = createEvmCommand({
  platform,
  commandAliases: ['mon', 'm'],
});

export default monad;
