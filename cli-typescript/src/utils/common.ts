import fs from 'fs';
import chalk from 'chalk';
import { execSync } from 'child_process';
import { confirm } from '@inquirer/prompts';
import {
  ICREATOR_TOKEN_INTERFACE_ID,
  rpcUrls,
  SUPPORTED_CHAINS,
  TRUE_HEX,
} from './constants';

export const confirmExit = async (): Promise<boolean> => {
  const answer = await confirm({
    message: 'Are you sure you want to exit?',
    default: false,
  });

  return answer;
};

/**
 * Helper function to execute shell commands.
 */
export const executeCommand = (command: string): string => {
  try {
    return execSync(command, { stdio: 'pipe' }).toString().trim();
  } catch (error: any) {
    console.error(`Error executing command: ${command}`);
    throw error;
  }
};

/**
 * Checks the native balance of the signer for a given chain.
 * @param chainId The chain ID to check the balance on.
 * @param signer The address of the signer.
 * @param rpcUrl The RPC URL.
 * @returns The native balance of the signer in a human-readable format (e.g., ETH, MATIC).
 * @throws Error if the balance retrieval fails.
 */
export const checkSignerNativeBalance = (
  signer: string,
  rpcUrl: string,
): string => {
  try {
    // Execute the `cast balance` command to get the balance of the signer
    const balanceCommand = `cast balance ${signer} --rpc-url "${rpcUrl}"`;
    const balance = executeCommand(balanceCommand);

    // Convert the balance from Wei to a human-readable format
    const fromWeiCommand = `cast from-wei ${balance}`;
    const humanReadableBalance = executeCommand(fromWeiCommand);

    // Format the balance to 3 decimal places
    return parseFloat(humanReadableBalance).toFixed(3);
  } catch (error: any) {
    console.error('Error checking signer native balance:', error.message);
    throw error;
  }
};

/**
 * Decodes an address from a given chunk of data.
 * Extracts the last 40 characters (20 bytes) and prepends "0x".
 * @param chunk The input string containing the encoded address.
 * @returns The decoded Ethereum address.
 * @throws Error if the input is invalid or too short.
 */
export const decodeAddress = (chunk: string | null): `0x${string}` => {
  if (!chunk || chunk.length < 40) {
    throw new Error(
      'Invalid input: chunk must be at least 40 characters long.',
    );
  }

  // Extract the last 40 characters (20 bytes for an Ethereum address)
  const address = chunk.slice(-40);

  // Prepend "0x" to make it a valid Ethereum address
  return `0x${address}`;
};

/**
 * Checks if the contract supports the ICreatorToken interface.
 * @param contractAddress The address of the contract to check.
 * @param rpcUrl The RPC URL of the blockchain network.
 * @param interfaceId The interface ID of ICreatorToken.
 * @param passwordOption Optional password option for the keystore e.g `--password <PASSWORD>`
 * @returns A boolean indicating whether the contract supports ICreatorToken.
 */
export const supportsICreatorToken = (
  chainId: SUPPORTED_CHAINS,
  contractAddress: `0x${string}`,
  passwordOption?: string,
): boolean => {
  try {
    console.log('Checking if contract supports ICreatorToken...');

    const rpcUrl = rpcUrls[chainId];

    // Construct the `cast call` command
    const command = `cast call ${contractAddress} "supportsInterface(bytes4)" ${ICREATOR_TOKEN_INTERFACE_ID} --rpc-url "${rpcUrl}" ${passwordOption ?? ''}`;

    // Execute the command and get the result
    const result = executeCommand(command);

    // Check if the result matches the expected TRUE_HEX value
    if (result === TRUE_HEX) {
      return true;
    } else {
      console.log(
        'Contract does not support ICreatorToken, skipping transfer validator setup.',
      );
      return false;
    }
  } catch (error: any) {
    console.error('Error checking ICreatorToken support:', error.message);
    return false;
  }
};

/**
 * Saves deployment data to a collection file.
 * @param contractAddress The deployed contract address.
 * @param initialOwner The initial owner of the contract.
 * @param collectionFile The path to the collection file.
 * @throws Error if the collection file is not found or if saving fails.
 */
export const saveDeploymentData = (
  contractAddress: string,
  initialOwner: string,
  collectionFile: string,
): void => {
  // Get the current timestamp
  const timestamp = Date.now();
  const deployedAt = new Date(timestamp).toISOString();

  // Check if the collection file exists
  if (!fs.existsSync(collectionFile)) {
    throw new Error(`Error: Collection file not found: ${collectionFile}`);
  }

  // Create deployment object
  const deploymentData = {
    contract_address: contractAddress,
    initial_owner: initialOwner,
    deployed_at: deployedAt,
  };

  // Read the existing collection file
  const fileContent = fs.readFileSync(collectionFile, 'utf-8');
  let collectionJson;
  try {
    collectionJson = JSON.parse(fileContent);
  } catch (error: any) {
    throw new Error(`Error parsing collection file: ${error.message}`);
  }

  // Add deployment data to the collection JSON
  collectionJson.deployment = deploymentData;

  // Write the updated JSON back to the collection file
  const tempFile = `${collectionFile}.tmp`;
  fs.writeFileSync(tempFile, JSON.stringify(collectionJson, null, 2));
  fs.renameSync(tempFile, collectionFile);

  console.log(`Deployment details added to ${collectionFile}`);
};

/**
 * Checks if a value is unset, null, or an empty string.
 * @param value The value to check.
 * @returns True if the value is null, undefined, or an empty string; otherwise, false.
 */
export const isUnsetOrNull = (value: string | null | undefined): boolean => {
  return value === null || value === undefined || value.trim() === '';
};

/**
 * Validates that an input value is not empty or undefined.
 * @param inputValue The value to validate.
 * @param inputName The name of the input field (used for error messages).
 * @throws Error if the input value is empty or undefined.
 */
export const checkInput = (
  inputValue: string | null | undefined,
  inputName: string,
): void => {
  if (!inputValue || inputValue.trim() === '') {
    throw new Error(`No input received for ${inputName}. Exiting...`);
  }
};

/**
 * Prompts the user to go to the main menu or exit the application.
 */
export const goToMainMenuOrExit = async (
  mainMenu: () => Promise<void>,
): Promise<void> => {
  const goToMainMenu = await confirm({
    message: 'Go to main menu?',
    default: true,
  });

  if (goToMainMenu) {
    console.clear();
    await mainMenu();
  } else {
    console.log(chalk.yellow('Exiting...'));
    process.exit(0);
  }
};

/**
 * Validates if a given string is a valid Ethereum address.
 * @param address The string to validate.
 * @returns True if the string is a valid Ethereum address, otherwise false.
 */
export const isValidEthereumAddress = (address: string): boolean => {
  return /^0x[a-fA-F0-9]{40}$/.test(address.trim());
};

/**
 * Formats an Ethereum address by showing the first 6 and last 4 characters, separated by "...".
 * @param address The Ethereum address to format.
 * @returns The collapsed address.
 */
export const collapseAddress = (address: string): string => {
  if (!isValidEthereumAddress(address)) {
    throw new Error('Invalid Ethereum address.');
  }

  const prefix = address.slice(0, 6);
  const suffix = address.slice(-4);
  return `${prefix}...${suffix}`;
};
