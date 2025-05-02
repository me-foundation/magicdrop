import { Option } from 'commander';
import {
  COLLECTION_DIR,
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

export const getTokenStandardOption = () =>
  new Option('-t --tokenStandard <tokenStandard>', 'the contract type')
    .choices([TOKEN_STANDARD.ERC721, TOKEN_STANDARD.ERC1155])
    .default(TOKEN_STANDARD.ERC721);

export const getChainOption = () =>
  new Option('-c --chain <chain>', 'Specify the chain to deploy to;')
    .choices(Array.from(Object.values(supportedChainNames)))
    .default(supportedChainNames[SUPPORTED_CHAINS.MONAD_TESTNET]);

export const getTotalTokensOption = () =>
  new Option(
    '--totalTokens <totalTokens>',
    `
    Total number of tokens in the collection. This value is used to calculate the minting stages.
    It is only used for ERC1155 tokenStandard.
    If you are using ERC721, this value is ignored.
    Notice: This value should match the number of tokens in the stages file. Otherwise, the contract will revert.
  `,
  );

export const getSetupWalletOption = () =>
  new Option(
    '-s --setupWallet',
    `
    Specify if a new wallet and signer account should be setup for the collection.
    Note: if you decide to ignore setup, you will need to setup the wallet and signer account manually.
    You can do this by creating a wallet.json file in the "${COLLECTION_DIR}/projects/<symbol>" directory.
  `,
  );

export const getSetupContractOption = () =>
  new Option(
    '-s --setupContract <setupContract>',
    'Specify if the contract should be set up after deployment (yes, no, deferred)',
  )
    .choices(['yes', 'no', 'deferred'])
    .default('deferred');

export const getForceOption = (
  description?: string,
  defaultValue?: boolean,
) => {
  return new Option(
    '-f --force',
    description ?? 'Force the action to be executed',
  ).default(defaultValue ?? false);
};

export const getStagesFileOption = () =>
  new Option(
    '--stagesFile <stagesFile>',
    `
    Path to the stages file. This file contains the minting stages for the collection.
  `,
  );

export const getTokenIdOption = () =>
  new Option(
    '--tokenId <tokenId>',
    `
    Specify the tokenId for ERC1155 collections.
  `,
  );

export const getGlobalWalletLimitOption = () => {
  return new Option(
    '-g --globalWalletLimit <globalWalletLimit>',
    'Specify the global wallet limit.',
  );
};

export const getMaxMintableSupplyOption = () =>
  new Option(
    '-m --maxMintableSupply <maxMintableSupply>',
    'Specify the max mintable supply.',
  );

export const getUriOption = () =>
  new Option(
    '-u --uri <uri>',
    'Specify the URI for the collection. Note: this will overwrite the existing URI.',
  );

export const getCosignerOption = () =>
  new Option(
    '-c --cosigner <cosigner>',
    'Specify the cosigner for the collection.',
  );

export const getExpiryTimestampOption = () =>
  new Option(
    '--expiry <expiry>',
    'Specify the expiry for the cosigner signature in seconds.',
  );

export const getFreezeThawOption = () =>
  new Option(
    '-c --choice <choice>',
    'Specify if the contract should be frozen or thawed (freeze, thaw)',
  ).choices(['freeze', 'thaw']);

export const getNewOwnerOption = () =>
  new Option(
    '--new-owner <newOwner>',
    'the address of the new contract/collection owner',
  );

export const getMinterOption = () =>
  new Option('--minter <minter>', 'the minter address for the collection.');

export const getMinterActionOption = () =>
  new Option('-a --action <action>', 'either add or remove minter').choices([
    'add',
    'remove',
  ]);

export const getIsMintableOption = () =>
  new Option('--mintable', 'is mintable or not.').default(false);

export const getTokenUriSuffixOption = () =>
  new Option(
    '--tokenUriSuffix <tokenUriSuffix>',
    'the tokenUriSuffix for the collection.',
  );

export const getReceiverOption = () =>
  new Option('-r --receiver <receiver>', 'the receiver address.');

export const getQtyOption = () => new Option('--qty <qty>', 'the token qty.');
