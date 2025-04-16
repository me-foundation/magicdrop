import fs from 'fs';
import path from 'path';
import chalk from 'chalk';

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

  process.env.DEFAULT_CONFIG_COMPLETE = 'true';
};
