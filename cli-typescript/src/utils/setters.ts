import path from 'path';
import { checkInput, collapseAddress, isUnsetOrNull } from './common';
import { showText } from './display';
import { confirm, input } from '@inquirer/prompts';
import {
  DEFAULT_ROYALTY_FEE,
  DEFAULT_ROYALTY_RECEIVER,
  rpcUrls,
  SUPPORTED_CHAINS,
  TOKEN_STANDARD,
} from './constants';
import {
  promptForChain,
  promptForCollectionFile,
  promptForCollectionName,
  promptForCollectionSymbol,
  promptForEthereumAddress,
  promptForNumericInput,
  promptForTokenStandard,
} from './prompters';

/**
 * Prompts the user to set the stages file if it is not already set.
 * @returns The updated stages file path.
 */
export const setStagesFile = async (): Promise<string> => {
  const stagesFile = process.env.STAGES_FILE;

  if (isUnsetOrNull(stagesFile)) {
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
  const baseDir = path.resolve(__dirname, '..');

  process.env.BASE_DIR = baseDir;
  return process.env.BASE_DIR;
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
    royaltyFee: Number(
      royaltyFee ?? process.env.DEFAULT_ROYALTY_FEE ?? DEFAULT_ROYALTY_FEE,
    ),
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
): Promise<number | number[]> => {
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

    return supplies;
  } else if (
    tokenStandard === TOKEN_STANDARD.ERC721 ||
    !isUnsetOrNull(tokenId)
  ) {
    // For ERC721 tokens or ERC1155 with a specific token ID
    showText(title, '> Set max mintable supply <');

    const supply = await promptForNumericInput('Enter max mintable supply');
    checkInput(supply.toString(), 'max mintable supply');

    return supply;
  } else {
    throw new Error('Unknown token standard');
  }
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
): Promise<number | number[]> => {
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

    return limits;
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

    return walletLimit;
  } else {
    throw new Error('Unknown token standard');
  }
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
 * Prompts the user to set the token URI suffix if it is not already set.
 * @param title The title to display in the prompt.
 * @param defaultTokenUriSuffix The default token URI suffix.
 * @returns The updated token URI suffix.
 */
export const setTokenUriSuffix = async (
  title: string,
  defaultTokenUriSuffix = '.json',
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
        validate: (value: string) => {
          if (!value.trim()) {
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
  }

  return Number(totalTokens!);
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

/**
 * Sets the RPC_URL env based on the provided chain ID.
 * @param chainId The chain ID for which to set the RPC URL.
 * @throws Error if the chain ID is unsupported.
 */
export const setRpcUrl = (chainId: SUPPORTED_CHAINS) => {
  const rpcUrl = rpcUrls[chainId as SUPPORTED_CHAINS];

  if (!rpcUrl) {
    throw new Error(`Unsupported chain ID: ${chainId}`);
  }

  process.env.RPC_URL = rpcUrl;
};

/**
 * Sets the CHAIN_ID env based on user input or existing environment variable.
 * @returns The selected chain ID.
 * @throws Error if the chain ID is unsupported or invalid.
 */
export const setChainID = async (): Promise<SUPPORTED_CHAINS> => {
  if (process.env.CHAIN_ID) {
    return Number(process.env.CHAIN_ID);
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

  return chainId;
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
