import fs from 'fs';
import { input, rawlist } from '@inquirer/prompts';
import path from 'path';
import {
  SUPPORTED_CHAINS,
  supportedChainNames,
  TOKEN_STANDARD,
} from './constants';
import { isValidEthereumAddress } from './common';

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
      validate: (value: string) => {
        if (
          value.trim().toLowerCase() === 'exit' ||
          value.trim().toLowerCase() === 'quit'
        ) {
          console.log('Exiting program...');
          process.exit(1);
        }

        if (!isValidEthereumAddress(value)) {
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

export const promptForChain = async (): Promise<string> => {
  const chainId = await rawlist({
    message: 'Choose a chain to deploy on:',
    choices: Object.keys(supportedChainNames).map((id) => ({
      name: supportedChainNames[id as SUPPORTED_CHAINS],
      value: id,
    })),
  });

  return chainId;
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

export const promptForCollectionName = async (): Promise<string> => {
  const collectionName = await input({
    message: 'Enter the collection name:',
    validate: (input: string) =>
      input ? true : 'Collection name is required.',
    required: true,
  });

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
