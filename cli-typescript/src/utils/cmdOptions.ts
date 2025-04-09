import { Option } from 'commander';
import { TOKEN_STANDARD } from './constants';

export const getEnvOption = (description?: string, defaultEnv?: string) => {
  const opt = new Option(
    '-e --env <env>',
    description ?? 'Environment to deploy to (e.g., mainnet, testnet)',
  );

  return !!defaultEnv ? opt.default(defaultEnv) : opt;
};

export const nonceOption = new Option('--nonce <nonce>', 'Transaction nonce');

export const deploymentGasLimitOption = new Option(
  '--deploymentGasLimit <deploymentGasLimit>',
  'Gas limit for deployment',
);

export const maxFeePerGasOption = new Option(
  '--maxFeePerGas <maxFeePerGas>',
  'Maximum fee per gas',
);

export const maxPriorityFeePerGasOption = new Option(
  '--maxPriorityFeePerGas <maxPriorityFeePerGas>',
  'Maximum priority fee per gas',
);

export const confirmationsToWaitOption = new Option(
  '--confirmationsToWait <confirmationsToWait>',
  'Number of confirmations to wait before considering deployment successful',
).default('1');

export const collectionSymbolOption = new Option(
  '--collectionSymbol <collectionSymbol>',
  'Symbol of the collection',
);

export const collectionNameOption = new Option(
  '--collectionName <collectionName>',
  'Name of the collection',
);

export const collectionConfigFile = new Option(
  '--collectionConfigFile <collectionConfigFile>',
  'Path to the collection project file',
);

export const tokenURISuffixOption = new Option(
  '--tokenURISuffix <tokenURISuffix>',
  'Suffix for the token URI',
);

export const maxMintableSupplyOption = new Option(
  '--maxMintableSupply <maxMintableSupply>',
  'Maximum mintable supply',
);

export const globalWalletLimitOption = new Option(
  '--globalWalletLimit <globalWalletLimit>',
  'Global wallet limit (0 for no limit)',
);

export const cosignerOption = new Option(
  '--cosigner <cosigner>',
  'Address of the co-signer server',
);

export const pathToContractBinaryOption = new Option(
  '--pathToContractBinary <pathToContractBinary>',
  'Path to the contract binary file in JSON format',
).default(
  'https://raw.githubusercontent.com/magiceden-oss/erc721m/release/artifacts/contracts/ERC721M.sol/ERC721M.json',
);

export const timestampExpirySecondsOption = new Option(
  '--timestampExpirySeconds <timestampExpirySeconds>',
  'How long a signature from the co-signer is valid for',
);

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
