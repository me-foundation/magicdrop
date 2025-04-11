import { Option } from 'commander';
import { TOKEN_STANDARD } from './constants';

export const getEnvOption = (description?: string, defaultEnv?: string) => {
  const opt = new Option(
    '-e --env <env>',
    description ?? 'Environment to deploy to (e.g., mainnet, testnet)',
  );

  return defaultEnv ? opt.default(defaultEnv) : opt;
};

export const tokenStandardOption = new Option(
  '--tokenStandard <tokenStandard>',
  `the contract type (${TOKEN_STANDARD.ERC721} or ${TOKEN_STANDARD.ERC1155})`,
)
  .choices([TOKEN_STANDARD.ERC721, TOKEN_STANDARD.ERC1155])
  .default(TOKEN_STANDARD.ERC721);

export const setupContractOption = new Option(
  '-s --setupContract <setupContract>',
  'Specify if the contract should be set up after deployment (yes, no, deferred)',
)
  .choices(['yes', 'no', 'deferred'])
  .default('deferred');
