import fs from 'fs';
import os from 'os';
import path from 'path';
import chalk from 'chalk';
import { executeCommand, getPasswordIfSet } from '../utils/common';
import { MAGIC_DROP_KEYSTORE } from '../utils/constants';

/**
 * Loads the signer by retrieving the wallet address using the password.
 * @throws Error if the wallet address cannot be retrieved or the password is incorrect.
 */
export const loadSigner = async (): Promise<void> => {
  console.log(chalk.blue('Loading signer... enter password if prompted'));

  const password = getPasswordIfSet();
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
 * Loads the private key by checking for an existing keystore file or creating one interactively.
 * @throws Error if the keystore creation fails.
 */
export const loadPrivateKey = async (): Promise<void> => {
  const homeDir = os.homedir();
  const magicDropKeystore =
    process.env.MAGIC_DROP_KEYSTORE || MAGIC_DROP_KEYSTORE;

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
