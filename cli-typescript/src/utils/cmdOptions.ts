import { Option } from 'commander';
import {
  SUPPORTED_CHAINS,
  supportedChainNames,
  TOKEN_STANDARD,
} from './constants';

export const getEnvOption = (
  choices?: string[],
  description?: string,
  defaultEnv?: string,
) => {
  const opt = new Option(
    '-e --env <env>',
    description ?? 'Environment to deploy to (e.g., mainnet, testnet)',
  );

  if (choices) {
    opt.choices(choices);
  }

  return defaultEnv ? opt.default(defaultEnv) : opt;
};

export const tokenStandardOption = new Option(
  '-t --tokenStandard <tokenStandard>',
  'the contract type',
)
  .choices([TOKEN_STANDARD.ERC721, TOKEN_STANDARD.ERC1155])
  .default(TOKEN_STANDARD.ERC721);

export const setupContractOption = new Option(
  '-s --setupContract <setupContract>',
  'Specify if the contract should be set up after deployment (yes, no, deferred)',
)
  .choices(['yes', 'no', 'deferred'])
  .default('deferred');

export const chainOption = new Option(
  '-c --chain <chain>',
  'Specify the chain to deploy to;',
)
  .choices(Array.from(Object.values(supportedChainNames)))
  .default(supportedChainNames[SUPPORTED_CHAINS.MONAD_TESTNET]);
