import fs from 'fs';
import os from 'os';
import path from 'path';
import chalk from 'chalk';
import { executeCommand } from './common';
import { MAGIC_DROP_KEYSTORE, TOKEN_STANDARD } from './constants';
import { Collection } from './types';
import dotenv from 'dotenv';
import { getExplorerContractUrl, getPasswordOptionIfSet } from './getters';

/**
 * Loads the signer by retrieving the wallet address using the password.
 * @throws Error if the wallet address cannot be retrieved or the password is incorrect.
 */
export const loadSigner = async (): Promise<void> => {
  console.log(chalk.blue('Loading signer... enter password if prompted'));

  const password = await getPasswordOptionIfSet();
  if (password) {
    try {
      // Execute the `cast wallet address` command to get the signer address
      const signer = executeCommand(`cast wallet address ${password}`);
      process.env.SIGNER = signer;
      console.log(chalk.green(`Signer loaded successfully: ${signer}`));
    } catch (error) {
      console.error(chalk.red('Error loading wallet: Check your password.'));
      process.exit(1);
    }
  } else {
    console.error(chalk.red('No password set. Skipping signer loading.'));
    process.exit(1);
  }
};

/**
 * Loads default configuration values from a `defaults.json` file and sets them in `process.env`.
 * Ensures the collections directory exists and loads the signer.
 * @throws Error if `defaults.json` is not found.
 */
export const loadDefaults = async (): Promise<void> => {
  const baseDir = process.env.BASE_DIR || path.resolve(__dirname, '..');
  let defaultsFile = path.join(baseDir, '../defaults.json');

  // Check if defaults.json exists in the expected location
  if (!fs.existsSync(defaultsFile)) {
    console.log(
      chalk.yellow(
        `defaults.json not found in ${defaultsFile}. Checking current directory...`,
      ),
    );
    defaultsFile = path.resolve('./defaults.json');
  }

  if (!fs.existsSync(defaultsFile)) {
    console.error(
      chalk.red('defaults.json not found in current directory. Exiting...'),
    );
    throw new Error('defaults.json not found.');
  }

  // Read and parse defaults.json
  const defaults = JSON.parse(fs.readFileSync(defaultsFile, 'utf-8'));

  // Set default values in process.env
  process.env.DEFAULT_COSIGNER = defaults.default_cosigner || '';
  process.env.DEFAULT_TIMESTAMP_EXPIRY =
    defaults.default_timestamp_expiry || '';
  process.env.DEFAULT_MINT_CURRENCY = defaults.default_mint_currency || '';
  process.env.DEFAULT_TOKEN_URI_SUFFIX =
    defaults.default_token_uri_suffix || '';
  process.env.DEFAULT_ROYALTY_RECEIVER =
    defaults.default_royalty_receiver || '';
  process.env.DEFAULT_ROYALTY_FEE =
    defaults.default_royalty_fee?.toString() || '';
  process.env.DEFAULT_MERKLE_ROOT = defaults.default_merkle_root || '';

  // Create collections directory if it doesn't exist
  const collectionsDir = path.join(baseDir, '../collections');
  if (!fs.existsSync(collectionsDir)) {
    console.log(
      chalk.green(`Creating collections directory at ${collectionsDir}...`),
    );
    fs.mkdirSync(collectionsDir, { recursive: true });
  }

  // Load environment variables from .env file if it exists
  const envFile = path.join(baseDir, '../.env');
  if (fs.existsSync(envFile)) {
    dotenv.config({ path: envFile });
  }

  // Load the signer
  await loadSigner();

  process.env.CONFIG_COMPLETE = 'true';
};

/**
 * Loads the private key by checking for an existing keystore file or creating one interactively.
 * @throws Error if the keystore creation fails.
 */
export const loadPrivateKey = async (): Promise<void> => {
  console.log(chalk.cyan('Loading private key'));
  const homeDir = os.homedir();
  const magicDropKeystore = MAGIC_DROP_KEYSTORE;

  const keystoreFile = path.join(
    homeDir,
    '.foundry',
    'keystores',
    magicDropKeystore,
  );

  // Check if the keystore file exists
  if (fs.existsSync(keystoreFile)) {
    console.log(chalk.green('Keystore file already exists.'));
    return;
  }

  console.log(
    chalk.yellow(
      '============================================================',
    ),
  );
  console.log('');
  console.log('Magic Drop CLI requires a private key to send transactions.');
  console.log(
    'This key controls all funds in the account, so it must be protected carefully.',
  );
  console.log('');
  console.log(
    'Magic Drop CLI will create an encrypted keystore for your private key.',
  );
  console.log(
    'You will be prompted to enter your private key and a password to encrypt it.',
  );
  console.log(
    'Learn more: https://book.getfoundry.sh/reference/cast/cast-wallet-import',
  );
  console.log('');
  console.log(
    'This password will be required to send transactions from your account.',
  );
  console.log('');
  console.log(
    chalk.yellow(
      '============================================================',
    ),
  );
  console.log('');

  try {
    // Run the `cast wallet import` command interactively
    executeCommand(`cast wallet import --interactive ${magicDropKeystore}`);
  } catch (error) {
    console.error(chalk.red('Failed to create keystore'));
    process.exit(1);
  }

  console.log('');
  console.log(chalk.green('Keystore created successfully.'));
  console.log(
    'You can store your password in .env to avoid entering it every time.',
  );
  console.log(
    chalk.cyan('echo "KEYSTORE_PASSWORD=<your_password>" >> cli/.env'),
  );
  console.log('');

  // Load the signer
  await loadSigner();

  process.exit(0);
};

/**
 * Loads a collection configuration file and extracts its details.
 * @param collectionFile The path to the collection file.
 * @returns An object containing the collection details.
 * @throws Error if the collection file is not found or invalid.
 */
export const loadCollection = (collectionFile: string): Collection => {
  if (!fs.existsSync(collectionFile)) {
    throw new Error(`Collection file not found: ${collectionFile}`);
  }

  const collectionData = JSON.parse(
    fs.readFileSync(collectionFile, 'utf-8'),
  ) as Collection;

  const {
    name,
    symbol,
    chainId,
    tokenStandard,
    maxMintableSupply,
    globalWalletLimit,
    mintCurrency,
    fundReceiver,
    royaltyReceiver,
    royaltyFee,
    stages,
    deployment,
    mintable,
    cosigner,
    uri,
  } = collectionData;

  let baseUri = '';
  let contractUri = '';
  if (tokenStandard === TOKEN_STANDARD.ERC721) {
    baseUri = uri;
  } else if (tokenStandard === TOKEN_STANDARD.ERC1155) {
    contractUri = uri;
  }

  const contractAddress = deployment?.contract_address || '';

  console.log('');
  console.log(chalk.green('Loaded Collection!'));
  console.log('');
  console.log(`Name: ${name}`);
  if (chainId) {
    console.log(`Chain: ${chainId}`);
  }
  if (contractAddress) {
    console.log(`Contract: ${contractAddress}`);
    console.log(getExplorerContractUrl(chainId.toString(), contractAddress));
  }

  // Set variables in process.env with uppercase snake case
  process.env.COLLECTION_NAME = name;
  process.env.COLLECTION_SYMBOL = symbol;
  process.env.CHAIN_ID = chainId.toString();
  process.env.TOKEN_STANDARD = tokenStandard;
  process.env.MAX_MINTABLE_SUPPLY = Array.isArray(maxMintableSupply)
    ? JSON.stringify(maxMintableSupply)
    : maxMintableSupply.toString();
  process.env.GLOBAL_WALLET_LIMIT = Array.isArray(globalWalletLimit)
    ? JSON.stringify(globalWalletLimit)
    : globalWalletLimit.toString();
  process.env.MINT_CURRENCY = mintCurrency;
  process.env.FUND_RECEIVER = fundReceiver;
  process.env.ROYALTY_RECEIVER = royaltyReceiver;
  process.env.ROYALTY_FEE = royaltyFee.toString();
  process.env.STAGES_JSON = JSON.stringify(stages);
  process.env.DEPLOYMENT_DATA = JSON.stringify(deployment);
  process.env.MINTABLE = mintable.toString();
  process.env.COSIGNER = cosigner;
  process.env.TOKEN_URI_SUFFIX =
    tokenStandard === TOKEN_STANDARD.ERC721
      ? collectionData.tokenUriSuffix.toString()
      : undefined;
  process.env.CONTRACT_URI = uri;
  process.env.USE_ERC721C =
    tokenStandard === TOKEN_STANDARD.ERC721
      ? collectionData.useERC721C.toString()
      : undefined;
  process.env.BASE_URI = baseUri;
  process.env.URI = contractUri;
  process.env.CONTRACT_ADDRESS = contractAddress;

  return collectionData;
};
