import fs from 'fs';
import chalk from 'chalk';
import { execSync } from 'child_process';
import { input, confirm, rawlist, password } from '@inquirer/prompts';
import {
  ABSTRACT_FACTORY_ADDRESS,
  ABSTRACT_REGISTRY_ADDRESS,
  DEFAULT_FACTORY_ADDRESS,
  DEFAULT_IMPL_ID,
  DEFAULT_LIST_ID,
  DEFAULT_REGISTRY_ADDRESS,
  DEFAULT_ROYALTY_FEE,
  DEFAULT_ROYALTY_RECEIVER,
  explorerUrls,
  ICREATOR_TOKEN_INTERFACE_ID,
  LIMITBREAK_TRANSFER_VALIDATOR_V3,
  LIMITBREAK_TRANSFER_VALIDATOR_V3_ABSTRACT,
  LIMITBREAK_TRANSFER_VALIDATOR_V3_BERACHAIN,
  MAGIC_DROP_KEYSTORE,
  MAGIC_DROP_KEYSTORE_FILE,
  MAGIC_EDEN_DEFAULT_LIST_ID,
  MAGIC_EDEN_POLYGON_LIST_ID,
  ME_TRANSFER_VALIDATOR_V3,
  rpcUrls,
  SUPPORTED_CHAINS,
  supportedChainNames,
  TOKEN_STANDARD,
  TRUE_HEX,
} from './constants';
import { Hex } from 'viem';
import path from 'path';
import { showText } from './display';
import { collapseAddress, isValidEthereumAddress } from './utils';
import { HexString } from '../../node_modules/ethers/lib.commonjs/utils/data';
import { TransactionData } from './types';

export const loadPrivateKey = async (): Promise<string> => {
  const privateKey = await input({
    message: 'Please enter your private key:',
    validate: (input) => input.length > 0 || 'Private key cannot be empty.',
  });

  return privateKey;
};

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

// const SUPPORTED_CHAINS = [
//     { id: '1', name: 'Ethereum Mainnet' },
//     { id: '5', name: 'Goerli Testnet' },
//     { id: '137', name: 'Polygon Mainnet' },
//     { id: '80001', name: 'Mumbai Testnet' },
// ];

export const getSymbolFromChainId = (chainId: string): string => {
  switch (chainId) {
    case SUPPORTED_CHAINS.ETHEREUM:
      return 'ETH';
    case SUPPORTED_CHAINS.POLYGON:
      return 'MATIC';
    case SUPPORTED_CHAINS.BSC:
      return 'BNB';
    case SUPPORTED_CHAINS.BASE:
      return 'BASE';
    case SUPPORTED_CHAINS.SEI:
      return 'SEI';
    case SUPPORTED_CHAINS.APECHAIN:
      return 'APE';
    case SUPPORTED_CHAINS.BERACHAIN:
      return 'BERA';
    case SUPPORTED_CHAINS.SEPOLIA:
      return 'SEP';
    case SUPPORTED_CHAINS.ARBITRUM:
      return 'ARB';
    case SUPPORTED_CHAINS.ABSTRACT:
      return 'ETH';
    case SUPPORTED_CHAINS.MONAD_TESTNET:
      return 'MON';
    case SUPPORTED_CHAINS.AVALANCHE:
      return 'AVAX';
    default:
      return 'Unknown';
  }
};

/**
 * Sets the RPC_URL env based on the provided chain ID.
 * @param chainId The chain ID for which to set the RPC URL.
 * @throws Error if the chain ID is unsupported.
 */
export const setRpcUrl = (chainId: string) => {
  const rpcUrl = rpcUrls[chainId as SUPPORTED_CHAINS];

  if (!rpcUrl) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }

  process.env.RPC_URL = rpcUrl;
};

/**
 * Helper functions for prompts
 */
const promptForChain = async (): Promise<string> => {
  const chainId = await rawlist({
    message: 'Choose a chain to deploy on:',
    choices: Object.keys(supportedChainNames).map((id) => ({
      name: supportedChainNames[id as SUPPORTED_CHAINS],
      value: id,
    })),
  });

  return chainId;
};

/**
 * Sets the CHAIN_ID env based on user input or existing environment variable.
 * @returns The selected chain ID.
 * @throws Error if the chain ID is unsupported or invalid.
 */
export const setChainID = async (): Promise<SUPPORTED_CHAINS> => {
  if (process.env.CHAIN_ID) {
    return process.env.CHAIN_ID as SUPPORTED_CHAINS;
  }

  // Prompt the user to select a chain
  const chainId = await promptForChain();

  if (!chainId) {
    throw new Error('Invalid chain selected.');
  }

  // Set the chain ID in the environment variable
  process.env.CHAIN_ID = String(chainId);

  // Set the RPC URL for the selected chain
  setRpcUrl(chainId);

  return chainId as SUPPORTED_CHAINS;
};

export const promptForTokenStandard = async (): Promise<TOKEN_STANDARD> => {
  const tokenStandard = await rawlist({
    message: 'Select the token standard:',
    choices: [
      { name: TOKEN_STANDARD.ERC721, value: TOKEN_STANDARD.ERC721 },
      { name: TOKEN_STANDARD.ERC1155, value: TOKEN_STANDARD.ERC1155 },
    ],
  });

  return tokenStandard;
};

export const setTokenStandard = async (): Promise<TOKEN_STANDARD> => {
  if (process.env.TOKEN_STANDARD) {
    return process.env.TOKEN_STANDARD as TOKEN_STANDARD;
  }

  // Prompt the user to select a token standard
  const tokenStandard = await promptForTokenStandard();
  if (!tokenStandard) {
    throw new Error('Invalid token standard selected.');
  }

  // Set the token standard in the environment variable
  process.env.TOKEN_STANDARD = tokenStandard;

  return tokenStandard;
};

export const promptForCollectionName = async (): Promise<string> => {
  const collectionName = await input({
    message: 'Enter the collection name:',
    validate: (input: HexString) =>
      input ? true : 'Collection name is required.',
    required: true,
  });

  return collectionName;
};

export const setCollectionName = async (): Promise<string> => {
  if (process.env.COLLECTION_NAME) {
    return process.env.COLLECTION_NAME;
  }

  // Prompt the user to enter a collection name
  const collectionName = await promptForCollectionName();
  if (!collectionName) {
    throw new Error('Invalid collection name provided.');
  }

  // Set the collection name in the environment variable
  process.env.COLLECTION_NAME = collectionName;

  return collectionName;
};

export const promptForCollectionSymbol = async (): Promise<string> => {
  const collectionSymbol = await input({
    message: 'Enter the collection symbol:',
    validate: (input) => (input ? true : 'Collection symbol is required.'),
    required: true,
  });

  return collectionSymbol;
};

export const setCollectionSymbol = async (): Promise<string> => {
  if (process.env.COLLECTION_SYMBOL) {
    return process.env.COLLECTION_SYMBOL;
  }

  // Prompt the user to enter a collection symbol
  const collectionSymbol = await promptForCollectionSymbol();
  if (!collectionSymbol) {
    throw new Error('Invalid collection symbol provided.');
  }

  // Set the collection symbol in the environment variable
  process.env.COLLECTION_SYMBOL = collectionSymbol;

  return collectionSymbol;
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

export const getFactoryAddress = (chainId: string): Hex => {
  if (chainId === SUPPORTED_CHAINS.ABSTRACT) {
    return ABSTRACT_FACTORY_ADDRESS;
  }

  return DEFAULT_FACTORY_ADDRESS;
};

export const getRegistryAddress = (chainId: string): Hex => {
  if (chainId === SUPPORTED_CHAINS.ABSTRACT) {
    return ABSTRACT_REGISTRY_ADDRESS;
  }

  return DEFAULT_REGISTRY_ADDRESS;
};

/**
 * The latest MagicDrop v1.0.1 implementation ID for each supported chain.
 * @param chainId The chain ID to check the balance on.
 * @param tokenStandard ERC721 or ERC1155
 * @param useERC721C use ERC721C
 * @returns implementation ID
 */
export const getImplId = (
  chainId: string,
  tokenStandard: TOKEN_STANDARD,
  useERC721C?: boolean,
): string => {
  if (tokenStandard !== TOKEN_STANDARD.ERC721 || !useERC721C) {
    return DEFAULT_IMPL_ID;
  }

  switch (chainId) {
    case SUPPORTED_CHAINS.ABSTRACT:
      return '3'; // ERC721C implementation ID / abstract
    case SUPPORTED_CHAINS.BASE:
      return '8';
    case SUPPORTED_CHAINS.ETHEREUM:
      return '7';
    case SUPPORTED_CHAINS.BERACHAIN:
      return '2';
    default:
      return '5';
  }
};

export const getStandardId = (tokenStandard: TOKEN_STANDARD): string => {
  switch (tokenStandard) {
    case TOKEN_STANDARD.ERC721:
      return '0';
    case TOKEN_STANDARD.ERC1155:
      return '1';
    default:
      throw new Error(`Unsupported token standard: ${tokenStandard}`);
  }
};

/**
 * Retrieves the password and account information if set.
 * @returns A string containing the password and account information, or undefined if not set. e.g `--password <PASSWORD> --account <MAGIC_DROP_KEYSTORE>`
 */
export const getPasswordOptionIfSet = async (): Promise<string> => {
  const keystorePassword = process.env.KEYSTORE_PASSWORD;

  if (keystorePassword) {
    return `--password ${keystorePassword} --account ${MAGIC_DROP_KEYSTORE}`;
  } else if (fs.existsSync(MAGIC_DROP_KEYSTORE_FILE)) {
    const passwrd = await password({
      message: 'Enter password:',
      mask: '*',
    });

    process.env.KEYSTORE_PASSWORD = passwrd;
    return `--password ${passwrd} --account ${MAGIC_DROP_KEYSTORE}`;
  }

  return '';
};

export const getUseERC721C = (): boolean => {
  return process.env.USE_ERC721C === 'true' ? true : false;
};

export const promptForConfirmation = async (
  message?: string,
  defaultValue?: boolean,
): Promise<boolean> => {
  return confirm({
    message: message ?? 'Please confirm',
    default: defaultValue ?? true,
  });
};

/**
 * Returns the transaction URL for a blockchain explorer based on the chain ID and transaction hash.
 * @param chainId The chain ID of the network.
 * @param txHash The transaction hash.
 * @returns The transaction URL.
 * @throws Error if the chain ID is unsupported.
 */
export const getExplorerTxUrl = (chainId: string, txHash: string): string => {
  const explorerUrl = explorerUrls[chainId as SUPPORTED_CHAINS];

  if (!explorerUrl) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }

  return `${explorerUrl}/tx/${txHash}`;
};

/**
 * Returns the contract URL for a blockchain explorer based on the chain ID and contract address.
 * @param chainId The chain ID of the network.
 * @param contractAddress The contract address.
 * @returns The contract URL.
 * @throws Error if the chain ID is unsupported.
 */
export const getExplorerContractUrl = (
  chainId: string,
  contractAddress: string,
): string => {
  const explorerUrl = explorerUrls[chainId as SUPPORTED_CHAINS];

  if (!explorerUrl) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }

  return `${explorerUrl}/address/${contractAddress}`;
};

/**
 * Extracts the contract address from deployment logs based on the event signature.
 * @param txnData The transaction data.
 * @param eventSig The event signature to match.
 * @returns The extracted contract address (without the `0x` prefix) or `null` if not found.
 */
export const getContractAddressFromLogs = (
  txnData: TransactionData,
  eventSig: string,
): string | null => {
  try {
    for (const log of txnData.logs) {
      const topic0 = log.topics[0];
      if (topic0 === eventSig) {
        return log.data.replace(/^0x/, ''); // Remove the `0x` prefix from the data
      }
    }

    return null; // Return null if no matching log is found
  } catch (error: any) {
    console.error('Error parsing deployment data:', error.message);
    throw new Error('Failed to extract contract address from logs.');
  }
};

/**
 * Decodes an address from a given chunk of data.
 * Extracts the last 40 characters (20 bytes) and prepends "0x".
 * @param chunk The input string containing the encoded address.
 * @returns The decoded Ethereum address.
 * @throws Error if the input is invalid or too short.
 */
export const decodeAddress = (chunk: string | null): Hex => {
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
  chainId: string,
  contractAddress: Hex,
  passwordOption?: string,
): boolean => {
  try {
    console.log('Checking if contract supports ICreatorToken...');

    const rpcUrl = rpcUrls[chainId as SUPPORTED_CHAINS];

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
 * Retrieves the transfer validator address based on the network (chain ID).
 * @param chainId The chain ID of the network.
 * @returns The transfer validator address for the given network.
 */
export const getTransferValidatorAddress = (chainId: string): string => {
  switch (chainId) {
    case SUPPORTED_CHAINS.APECHAIN:
    case SUPPORTED_CHAINS.SEI:
      return ME_TRANSFER_VALIDATOR_V3;

    case SUPPORTED_CHAINS.ARBITRUM:
    case SUPPORTED_CHAINS.BASE:
    case SUPPORTED_CHAINS.ETHEREUM:
    case SUPPORTED_CHAINS.SEPOLIA:
      return LIMITBREAK_TRANSFER_VALIDATOR_V3;

    case SUPPORTED_CHAINS.ABSTRACT:
      return LIMITBREAK_TRANSFER_VALIDATOR_V3_ABSTRACT;

    case SUPPORTED_CHAINS.BERACHAIN:
      return LIMITBREAK_TRANSFER_VALIDATOR_V3_BERACHAIN;

    default:
      return LIMITBREAK_TRANSFER_VALIDATOR_V3;
  }
};

export const getZksyncFlag = (chainId: string): string => {
  if (chainId === SUPPORTED_CHAINS.ABSTRACT) return '--zksync';

  return '';
};

/**
 * Retrieves the transfer validator list ID based on the network (chain ID).
 * @param chainId The chain ID of the network.
 * @returns The transfer validator list ID for the given network.
 */
export const getTransferValidatorListId = (chainId: string): string => {
  switch (chainId) {
    case SUPPORTED_CHAINS.BERACHAIN:
      return DEFAULT_LIST_ID;

    case SUPPORTED_CHAINS.POLYGON:
      return MAGIC_EDEN_POLYGON_LIST_ID;

    default:
      return MAGIC_EDEN_DEFAULT_LIST_ID;
  }
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
 * Prompts the user to select a collection file from a directory.
 * @param promptMessage The message to display to the user.
 * @param directory The directory to browse for files. Defaults to "../collections".
 * @returns The selected file path.
 * @throws Error if the selected file does not exist or the user cancels the operation.
 */
export const promptForCollectionFile = async (
  promptMessage = 'Select a collection file:',
  directory: string = path.join(
    process.env.BASE_DIR ?? __dirname,
    '../collections',
  ),
): Promise<string> => {
  try {
    // Ensure the directory exists
    if (!fs.existsSync(directory)) {
      throw new Error(`Directory not found: ${directory}`);
    }

    // Get the list of files and directories in the specified directory
    const files = fs.readdirSync(directory);

    if (files.length === 0) {
      throw new Error(`No files found in directory: ${directory}`);
    }

    // Prompt the user to select a file or directory
    const selectedFile = await rawlist<string>({
      message: promptMessage,
      choices: files,
    });

    const selectedPath = path.join(directory, selectedFile);

    // Check if the selected path is a directory
    if (fs.lstatSync(selectedPath).isDirectory()) {
      // Recursively call the function with the selected directory
      return await promptForCollectionFile(promptMessage, selectedPath);
    }

    // Check if the selected path is a valid file
    if (fs.existsSync(selectedPath) && fs.lstatSync(selectedPath).isFile()) {
      return selectedPath;
    } else {
      throw new Error(`Invalid file selected: ${selectedPath}`);
    }
  } catch (error: any) {
    console.error(error.message);
    throw new Error('Failed to select a collection file.');
  }
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
 * Prompts the user to input a numeric value.
 * The user can type "exit" or "quit" to terminate the program.
 * @param promptMessage The message to display to the user.
 * @returns The numeric input provided by the user.
 * @throws Error if the user exits the program.
 */
export const promptForNumericInput = async (
  promptMessage: string,
): Promise<number> => {
  while (true) {
    const number = await input({
      message: `${promptMessage} (or 'exit' to quit):`,
      validate: (value) => {
        if (
          value.trim().toLowerCase() === 'exit' ||
          value.trim().toLowerCase() === 'quit'
        ) {
          console.log('Exiting program...');
          process.exit(1); // Exit the program
        }

        // Validate that the input is numeric
        if (isNaN(Number(value))) {
          return 'Please enter a valid numeric value.';
        }

        return true;
      },
    });

    // If the input is numeric, return it
    if (!isNaN(Number(number))) {
      return parseInt(number, 10);
    }
  }
};

/**
 * Prompts the user to set the URI for ERC1155 tokens if it is not already set.
 * @param title The title to display in the prompt.
 * @returns The updated URI.
 */
export const set1155Uri = async (title: string): Promise<string> => {
  const uri = process.env.CONTRACT_URI;

  if (isUnsetOrNull(uri)) {
    // Display the title
    showText(title, '> Enter new URI <');

    // Prompt the user to enter the new URI
    const newUri = await input({
      message: 'Enter new URI:',
      validate: (input) => {
        if (!input.trim()) {
          return 'URI cannot be empty.';
        }

        return true;
      },
    });

    // Validate the input
    checkInput(newUri, 'URI');
    process.env.CONTRACT_URI = newUri;

    console.clear();
    return newUri;
  }

  return uri!;
};

/**
 * Prompts the user to set the total number of ERC1155 tokens if not already set.
 * @param totalTokens The current total number of tokens.
 * @param title The title to display in the prompt.
 * @returns The updated total number of tokens.
 */
export const setNumberOf1155Tokens = async (title: string): Promise<number> => {
  let totalTokens = process.env.TOTAL_TOKENS;

  if (isUnsetOrNull(totalTokens)) {
    // Display the title
    showText(title, '> Enter total tokens <');
    showText(
      'Notice: This value should match the number of tokens in the stages file. Otherwise, the contract will revert.',
      '',
      false,
      false,
    );

    // Prompt the user to enter the total number of tokens
    const totalTokensInput = await promptForNumericInput('Enter total tokens');
    totalTokens = String(totalTokensInput);

    checkInput(totalTokens, 'total tokens');
    console.clear();

    process.env.TOTAL_TOKENS = totalTokens;
  }

  return Number(totalTokens!);
};

/**
 * Prompts the user to set the base URI if it is not already set.
 * @param title The title to display in the prompt.
 * @returns The updated base URI.
 */
export const setBaseUri = async (title: string): Promise<string> => {
  const baseUri = process.env.BASE_URI;

  if (isUnsetOrNull(baseUri)) {
    // Display the title
    showText(title, '> Enter the base URI <');

    // Prompt the user to enter the base URI
    const newBaseUri = await input({
      message: 'Enter base URI:',
      validate: (input) => {
        if (!input.trim()) {
          return 'Base URI cannot be empty.';
        }
        return true;
      },
    });

    // Validate the input
    checkInput(newBaseUri, 'base URI');
    process.env.BASE_URI = newBaseUri;

    console.clear();
    return newBaseUri;
  }

  return baseUri!;
};

/**
 * Prompts the user to set the token URI suffix if it is not already set.
 * @param title The title to display in the prompt.
 * @param defaultTokenUriSuffix The default token URI suffix.
 * @returns The updated token URI suffix.
 */
export const setTokenUriSuffix = async (
  title: string,
  defaultTokenUriSuffix = process.env.TOKEN_URI_SUFFIX || '.json',
): Promise<string> => {
  const tokenUriSuffix = process.env.TOKEN_URI_SUFFIX;

  if (isUnsetOrNull(tokenUriSuffix)) {
    // Display the title
    showText(title, '> Set token URI suffix <');

    // Prompt the user to confirm if they want to override the default suffix
    const override = await confirm({
      message: `Override default token URI suffix? (${defaultTokenUriSuffix})`,
      default: false,
    });

    let newTokenUriSuffix: string;

    if (override) {
      // Prompt the user to enter a new token URI suffix
      const inputSuffix = await input({
        message: 'Enter token URI suffix:',
        default: '.json',
        validate: (input) => {
          if (!input.trim()) {
            return 'Token URI suffix cannot be empty.';
          }
          return true;
        },
      });

      newTokenUriSuffix = inputSuffix;
    } else {
      // Use the default token URI suffix
      newTokenUriSuffix = defaultTokenUriSuffix;
    }

    process.env.TOKEN_URI_SUFFIX = newTokenUriSuffix;

    return newTokenUriSuffix;
  }

  return tokenUriSuffix!;
};

/**
 * Prompts the user to set the token ID if it is not already set.
 * @param title The title to display in the prompt.
 * @returns The updated token ID as a number.
 */
export const setTokenId = async (title: string): Promise<number> => {
  const tokenId = process.env.TOKEN_ID;

  if (isUnsetOrNull(tokenId) || isNaN(Number(tokenId!))) {
    // Display the title
    showText(title, '> Enter token ID <');

    // Prompt the user to enter the token ID
    const newTokenId = await promptForNumericInput('Enter token ID');

    // Validate the input
    checkInput(newTokenId.toString(), 'token ID');

    process.env.TOKEN_ID = newTokenId.toString();

    console.clear();
    return newTokenId;
  }

  return Number(tokenId!);
};

/**
 * Prompts the user to set the global wallet limit based on the token standard.
 * @param tokenStandard The token standard (e.g., "ERC1155" or "ERC721").
 * @param totalTokens The total number of tokens (for ERC1155).
 * @param title The title to display in the prompt.
 * @param tokenId Optional token ID (for specific tokens).
 * @returns The global wallet limit as a string or array.
 */
export const setGlobalWalletLimit = async (
  tokenStandard: string,
  totalTokens: number,
  title: string,
  tokenId?: string,
): Promise<string> => {
  const globalWalletLimit = process.env.GLOBAL_WALLET_LIMIT;

  if (!isUnsetOrNull(globalWalletLimit)) return globalWalletLimit!;

  if (tokenStandard === TOKEN_STANDARD.ERC1155 && isUnsetOrNull(tokenId)) {
    // For ERC1155 tokens without a specific token ID
    showText(title, '> Set global wallet limit for each token <');

    const limits: number[] = [];
    for (let i = 0; i < totalTokens; i++) {
      const tokenLimit = await promptForNumericInput(
        `Enter global wallet limit for token ${i} (0 for no limit)`,
      );
      checkInput(tokenLimit.toString(), `global wallet limit for token ${i}`);
      limits.push(tokenLimit);
    }

    process.env.GLOBAL_WALLET_LIMIT = JSON.stringify(limits);

    return JSON.stringify(limits);
  } else if (
    tokenStandard === TOKEN_STANDARD.ERC721 ||
    !isUnsetOrNull(tokenId)
  ) {
    // For ERC721 tokens or ERC1155 with a specific token ID
    showText(title, '> Set global wallet limit <');

    const walletLimit = await promptForNumericInput(
      'Enter global wallet limit (0 for no limit)',
    );
    checkInput(walletLimit.toString(), 'global wallet limit');

    process.env.GLOBAL_WALLET_LIMIT = walletLimit.toString();
    return walletLimit.toString();
  } else {
    throw new Error('Unknown token standard');
  }
};

/**
 * Prompts the user to set the maximum mintable supply based on the token standard.
 * @param tokenStandard The token standard (e.g., "ERC1155" or "ERC721").
 * @param totalTokens The total number of tokens (for ERC1155).
 * @param title The title to display in the prompt.
 * @param tokenId Optional token ID (for specific tokens).
 * @returns The maximum mintable supply as a string or array.
 */
export const setMaxMintableSupply = async (
  tokenStandard: string,
  totalTokens: number,
  title: string,
  tokenId?: string,
): Promise<string> => {
  const maxMintableSupply = process.env.MAX_MINTABLE_SUPPLY;

  if (!isUnsetOrNull(maxMintableSupply)) {
    return maxMintableSupply!;
  }

  if (tokenStandard === TOKEN_STANDARD.ERC1155 && isUnsetOrNull(tokenId)) {
    // For ERC1155 tokens without a specific token ID
    showText(title, '> Set max mintable supply for each token <');

    const supplies: number[] = [];
    for (let i = 0; i < totalTokens; i++) {
      const tokenSupply = await promptForNumericInput(
        `Enter max mintable supply for token ${i}`,
      );
      checkInput(tokenSupply.toString(), `max mintable supply for token ${i}`);
      supplies.push(tokenSupply);
    }

    process.env.MAX_MINTABLE_SUPPLY = JSON.stringify(supplies);

    return JSON.stringify(supplies);
  } else if (
    tokenStandard === TOKEN_STANDARD.ERC721 ||
    !isUnsetOrNull(tokenId)
  ) {
    // For ERC721 tokens or ERC1155 with a specific token ID
    showText(title, '> Set max mintable supply <');

    const supply = await promptForNumericInput('Enter max mintable supply');
    checkInput(supply.toString(), 'max mintable supply');

    process.env.MAX_MINTABLE_SUPPLY = supply.toString();

    return supply.toString();
  } else {
    throw new Error('Unknown token standard');
  }
};

/**
 * Prompts the user to input a valid Ethereum address.
 * The user can type "exit" or "quit" to terminate the program.
 * @param promptMessage The message to display to the user.
 * @returns The valid Ethereum address provided by the user.
 * @throws Error if the user exits the program or provides an invalid address.
 */
export const promptForEthereumAddress = async (
  promptMessage: string,
): Promise<string> => {
  while (true) {
    const address = await input({
      message: `${promptMessage} (or 'exit' to quit):`,
      validate: (input) => {
        if (
          input.trim().toLowerCase() === 'exit' ||
          input.trim().toLowerCase() === 'quit'
        ) {
          console.log('Exiting program...');
          process.exit(1);
        }

        if (!isValidEthereumAddress(input)) {
          return 'Invalid Ethereum address. Please enter a valid address.';
        }

        return true;
      },
    });

    // If the address is valid, return it
    if (isValidEthereumAddress(address)) {
      return address.trim();
    }
  }
};

/**
 * Prompts the user to set the mint currency if it is not already set.
 * @param title The title to display in the prompt.
 * @param defaultMintCurrency The default mint currency to use if not overridden.
 * @returns The updated mint currency.
 */
export const setMintCurrency = async (
  title: string,
  defaultMintCurrency: string,
): Promise<string> => {
  const mintCurrency = process.env.MINT_CURRENCY;

  if (isUnsetOrNull(mintCurrency)) {
    // Display the title
    showText(title, '> Set mint currency <');

    // Prompt the user to confirm if they want to override the default mint currency
    const override = await confirm({
      message: `Override default mint currency? (${defaultMintCurrency})`,
      default: false,
    });

    let newMintCurrency: string;

    if (override) {
      // Prompt the user to enter a new mint currency
      newMintCurrency = await promptForEthereumAddress(
        'Mint currency (default: Native Gas Token)',
      );
    } else {
      // Use the default mint currency
      newMintCurrency = defaultMintCurrency;
    }

    // Validate the input
    checkInput(newMintCurrency, 'mint currency');

    process.env.MINT_CURRENCY = newMintCurrency;

    console.clear();
    return newMintCurrency;
  }

  return mintCurrency!;
};

/**
 * Prompts the user to set the fund receiver address if it is not already set.
 * @param title The title to display in the prompt.
 * @param signer The default signer address to use if the user does not override.
 * @returns The updated fund receiver address.
 */
export const setFundReceiver = async (
  title: string,
  signer: string,
): Promise<string> => {
  const fundReceiver = process.env.FUND_RECEIVER;

  if (isUnsetOrNull(fundReceiver)) {
    // Display the title
    showText(title, '> Set fund receiver <');

    // Prompt the user to confirm if they want to override the default fund receiver
    const override = await confirm({
      message: `Override fund receiver? (default: ${collapseAddress(signer)})`,
      default: false,
    });

    let newFundReceiver: string;

    if (override) {
      // Prompt the user to enter a new fund receiver address
      newFundReceiver = await promptForEthereumAddress(
        'Fund receiver (e.g., 0x000...000)',
      );
    } else {
      // Use the default signer address as the fund receiver
      newFundReceiver = signer;
    }

    // Validate the input
    checkInput(newFundReceiver, 'fund receiver');

    process.env.FUND_RECEIVER = newFundReceiver;

    console.clear();
    return newFundReceiver;
  }

  return fundReceiver!;
};

/**
 * Prompts the user to set royalties if they are not already set.
 * @param title The title to display in the prompt.
 * @returns An object containing the updated royalty receiver and royalty fee.
 */
export const setRoyalties = async (
  title: string,
): Promise<{ royaltyReceiver: string; royaltyFee: number }> => {
  const royaltyReceiver = process.env.ROYALTY_RECEIVER;
  const royaltyFee = process.env.ROYALTY_FEE;

  let res = {
    royaltyReceiver:
      royaltyReceiver ??
      process.env.DEFAULT_ROYALTY_RECEIVER ??
      DEFAULT_ROYALTY_RECEIVER,
    royaltyFee:
      Number(royaltyFee ?? process.env.DEFAULT_ROYALTY_FEE) ??
      DEFAULT_ROYALTY_FEE,
  };

  if (isUnsetOrNull(royaltyReceiver) && isUnsetOrNull(royaltyFee)) {
    // Display the title
    showText(title, '> Do you want to set royalties? <');

    // Prompt the user to confirm if they want to use royalties
    const useRoyalties = await confirm({
      message: 'Use royalties?',
      default: false,
    });

    if (useRoyalties) {
      // Set royalty receiver
      showText(title, '> Set royalty receiver <');
      const newRoyaltyReceiver = await promptForEthereumAddress(
        'Enter royalty receiver address',
      );
      checkInput(newRoyaltyReceiver, 'royalty receiver');

      // Set royalty fee numerator
      showText(title, '> Set royalty fee numerator <');
      const newRoyaltyFee = await promptForNumericInput(
        'Enter royalty fee numerator (e.g., 500 for 5%)',
      );
      checkInput(newRoyaltyFee.toString(), 'royalty fee numerator');

      process.env.ROYALTY_RECEIVER = newRoyaltyReceiver;
      process.env.ROYALTY_FEE = newRoyaltyFee.toString();

      console.clear();

      res = {
        royaltyReceiver: newRoyaltyReceiver,
        royaltyFee: newRoyaltyFee,
      };
    }
  }

  return res;
};

/**
 * Prompts the user to set the stages file if it is not already set.
 * @returns The updated stages file path.
 */
export const setStagesFile = async (): Promise<string> => {
  const stagesFile = process.env.STAGES_FILE;
  const stagesJson = process.env.STAGES_JSON;

  if (isUnsetOrNull(stagesFile) && isUnsetOrNull(stagesJson)) {
    console.log('> Set stages file <');

    const selectedFile = await promptForCollectionFile(
      'Enter stages JSON file',
    );
    process.env.STAGES_FILE = selectedFile;

    console.clear();
    return selectedFile;
  }

  return stagesFile || '';
};

/**
 * Gets the base directory of the current script.
 * @returns The absolute path to the base directory.
 */
export const setBaseDir = (): string => {
  let baseDir = path.resolve(__dirname);
  if (baseDir.includes('/dist')) {
    baseDir = path.resolve(__dirname, '..');
  }

  process.env.BASE_DIR = baseDir;
  return process.env.BASE_DIR;
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
