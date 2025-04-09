import path from 'path';
import fs from 'fs';
import { executeCommand } from './common';
import {
  DEFAULT_MINT_CURRENCY,
  rpcUrls,
  SUPPORTED_CHAINS,
  TOKEN_STANDARD,
  TRUE_HEX,
} from './constants';
import {
  confirmSetup,
  printSignerWithBalance,
  printTransactionHash,
  showText,
} from './display';
import { TransactionData } from './types';
import {
  getTransferValidatorAddress,
  getTransferValidatorListId,
  getZksyncFlag,
} from './getters';
import {
  set1155Uri,
  setBaseUri,
  setFundReceiver,
  setGlobalWalletLimit,
  setMaxMintableSupply,
  setMintCurrency,
  setNumberOf1155Tokens,
  setRoyalties,
  setStagesFile,
  setTokenUriSuffix,
} from './setters';

/**
 * Sets the transfer validator for a contract.
 * @param contractAddress The address of the contract.
 * @param chainId The chain ID of the network.
 * @param rpcUrl The RPC URL of the blockchain network.
 * @param password Optional password for the keystore.
 * @throws Error if the operation fails.
 */
export const setTransferValidator = (
  contractAddress: string,
  chainId: SUPPORTED_CHAINS,
  password?: string,
): void => {
  try {
    const rpcUrl = rpcUrls[chainId as SUPPORTED_CHAINS];

    // Get the transfer validator address for the given chain ID
    const tfAddress = getTransferValidatorAddress(chainId);
    console.log(`Setting transfer validator to ${tfAddress}...`);

    // Construct the `cast send` command
    const passwordOption = password ? `--password ${password}` : '';
    const zksyncFlag = getZksyncFlag(chainId);
    const command = `cast send ${contractAddress} "setTransferValidator(address)" ${tfAddress} ${passwordOption} ${zksyncFlag} --rpc-url "${rpcUrl}" --json`;

    // Execute the command and capture the output
    const output = executeCommand(command);

    // Print the transaction hash
    printTransactionHash(output, chainId);

    console.log('Transfer validator set.');
    console.log('');
  } catch (error: any) {
    console.error('Error setting transfer validator:', error.message);
    throw new Error('Failed to set transfer validator.');
  }
};

/**
 * Sets the transfer list for a contract.
 * @param contractAddress The address of the contract.
 * @param chainId The chain ID of the network.
 * @param password Optional password for the keystore.
 * @throws Error if the operation fails.
 */
export const setTransferList = async (
  contractAddress: Hex,
  chainId: SUPPORTED_CHAINS,
  password?: string,
): Promise<void> => {
  try {
    // Get the transfer validator list ID for the given chain ID
    const tfListId = getTransferValidatorListId(chainId);
    console.log(`Setting transfer list to list ID ${tfListId}...`);

    // Get the transfer validator address
    const tfAddress = getTransferValidatorAddress(chainId);

    // Construct the `cast send` command
    const rpcUrl = rpcUrls[chainId as SUPPORTED_CHAINS];
    const passwordOption = password ? `--password ${password}` : '';
    const zksyncFlag = getZksyncFlag(chainId);
    const command = `cast send ${tfAddress} "applyListToCollection(address,uint120)" ${contractAddress} ${tfListId} ${passwordOption} ${zksyncFlag} --rpc-url "${rpcUrl}" --json`;

    const output = executeCommand(command);

    printTransactionHash(output, chainId);

    console.log('Transfer list set.');
    console.log('');
  } catch (error: any) {
    console.error('Error setting transfer list:', error.message);
    throw new Error('Failed to set transfer list.');
  }
};

/**
 * Freeze a contract.
 */
export const freezeContract = (
  contractAddress: Hex,
  chainId: SUPPORTED_CHAINS,
  password?: string,
) => {
  console.log('Freezing contract... this will take a moment.');

  const rpcUrl = rpcUrls[chainId as SUPPORTED_CHAINS];
  const passwordOption = password ? `--password ${password}` : '';
  const zksyncFlag = getZksyncFlag(chainId);

  const command = `cast send ${contractAddress} "setTransferable(bool)" false ${passwordOption} ${zksyncFlag} --rpc-url "${rpcUrl}" --json`;
  const output = executeCommand(command);

  printTransactionHash(output, chainId);

  console.log('Token transfers frozen.');
};

/**
 * Checks if the contract setup is locked.
 * @param contractAddress The address of the contract.
 * @param rpcUrl The RPC URL of the blockchain network.
 * @param passwordOption Optional password option for the keystore e.g `--password <PASSWORD >`
 * @throws Error if the contract setup is locked.
 */
export const checkSetupLocked = (
  contractAddress: string,
  rpcUrl: string,
  passwordOption?: string,
): void => {
  try {
    console.log('Checking if contract setup is locked...');

    // Construct the `cast call` command
    const command = `cast call ${contractAddress} "isSetupLocked()" --rpc-url "${rpcUrl}" ${passwordOption ?? ''}`;

    const result = executeCommand(command);

    // Check if the result indicates the setup is locked
    if (result === TRUE_HEX) {
      showText(
        'This contract has already been setup. Please use other commands from the "Manage Contracts" menu to update the contract.',
      );
      process.exit(1);
    }

    console.log('Contract setup is not locked. Proceeding...');
  } catch (error: any) {
    console.error('Error checking setup lock:', error.message);
    throw error;
  }
};

/**
 * Processes the stages file and generates the required output.
 * @param params An object containing the required parameters for processing stages.
 * @returns the stageData
 * @throws Error if the process fails or the output file is not found.
 */
export const processStages = async (params: {
  collectionFile: string;
  stagesFile?: string;
  stagesJson?: string;
  tokenStandard: string;
  baseDir: string;
}): Promise<string> => {
  const {
    collectionFile,
    stagesFile = '',
    stagesJson,
    tokenStandard,
    baseDir,
  } = params;

  const outputFileDir = path.dirname(collectionFile);
  console.log(`Output file directory: ${outputFileDir}`);

  try {
    // Execute the script to process stages
    executeCommand(
      `npx ts-node "${path.join(
        baseDir,
        '../../scripts/utils/getStagesData.ts',
      )}" "${stagesFile}" '${stagesJson}' "${outputFileDir}" "${tokenStandard}"`,
    );
  } catch (error: any) {
    console.error('Error: Failed to get stages data', error.message);
    throw new Error('Failed to get stages data');
  }

  // Check if the output file exists
  const outputFilePath = path.join(outputFileDir, 'stagesInput.tmp');

  if (!fs.existsSync(outputFilePath)) {
    console.error(`Error: Output file not found: ${outputFilePath}`);
    throw new Error(`Output file not found: ${outputFilePath}`);
  }

  // Read the stages data
  const stagesData = fs.readFileSync(outputFilePath, 'utf-8');

  // Delete the temporary file
  fs.unlinkSync(outputFilePath);

  return stagesData;
};

/**
 * Sets up an existing collection contract.
 * @param params
 * @throws Error if the operation fails.
 */
export const setupContract = async (params: {
  contractAddress: string;
  chainId: SUPPORTED_CHAINS;
  tokenStandard: TOKEN_STANDARD;
  collectionFile: string;
  signer: string;
  baseDir?: string;
  uri?: string;
  tokenUriSuffix?: string;
  passwordOption?: string;
  title?: string;
  stagesJson?: string;
  totalTokens?: number;
  globalWalletLimit?: number | number[];
  maxMintableSupply?: number | number[];
  fundReceiver?: string;
  royaltyReceiver?: string;
  royaltyFee?: number;
  mintCurrency: string;
}): Promise<void> => {
  const {
    contractAddress,
    chainId,
    tokenStandard,
    collectionFile,
    signer,
    passwordOption,
    stagesJson,
    title = 'Setup an existing collection',
    baseDir = __dirname,
  } = params;

  try {
    console.clear();

    const rpcUrl = rpcUrls[chainId as SUPPORTED_CHAINS];

    checkSetupLocked(contractAddress, rpcUrl, passwordOption);

    const stagesFile = !stagesJson ? await setStagesFile() : undefined;

    // Define setup selector based on token standard
    let setupSelector = '';
    let uri = '';
    let baseUri = '';
    let tokenUriSuffix = '';
    let totalTokens = 0;

    if (tokenStandard === TOKEN_STANDARD.ERC721) {
      baseUri = params.uri ?? (await setBaseUri(title));
      tokenUriSuffix =
        params.tokenUriSuffix ?? (await setTokenUriSuffix(title));
      setupSelector =
        'setup(string,string,uint256,uint256,address,address,(uint80,uint80,uint32,bytes32,uint24,uint256,uint256)[],address,uint96)';
    } else if (tokenStandard === TOKEN_STANDARD.ERC1155) {
      totalTokens = params.totalTokens ?? (await setNumberOf1155Tokens(title));
      uri = params.uri ?? (await set1155Uri(title));
      setupSelector =
        'setup(string,uint256[],uint256[],address,address,(uint80[],uint80[],uint32[],bytes32[],uint24[],uint256,uint256)[],address,uint96)';
    } else {
      throw new Error('Unknown token standard');
    }

    const globalWalletLimit =
      params.globalWalletLimit ??
      (await setGlobalWalletLimit(tokenStandard, totalTokens, title));
    const maxMintableSupply =
      params.maxMintableSupply ??
      (await setMaxMintableSupply(tokenStandard, totalTokens, title));
    const mintCurrency =
      params.mintCurrency ||
      (await setMintCurrency(title, DEFAULT_MINT_CURRENCY));
    const fundReceiver =
      params.fundReceiver ?? (await setFundReceiver(title, signer));
    const { royaltyFee, royaltyReceiver } =
      !params.royaltyFee || !params.royaltyReceiver
        ? await setRoyalties(title)
        : {
            royaltyFee: params.royaltyFee,
            royaltyReceiver: params.royaltyReceiver,
          };

    await printSignerWithBalance(chainId);
    await confirmSetup({
      chainId,
      tokenStandard,
      contractAddress,
      maxMintableSupply,
      globalWalletLimit,
      mintCurrency,
      royaltyReceiver,
      royaltyFee,
      stagesFile,
      stagesJson,
      fundReceiver,
    });

    // Process stages file
    console.log('Processing stages file... this will take a moment.');
    const stagesData = await processStages({
      collectionFile,
      stagesFile,
      stagesJson,
      tokenStandard,
      baseDir,
    });

    console.log('Setting up contract... this will take a moment.');

    // Construct the `cast send` command
    const zksyncFlag = getZksyncFlag(chainId);
    const command = `cast send ${contractAddress} \
            "${setupSelector}" \
            ${uri} \
            ${baseUri} \
            ${tokenUriSuffix} \
            ${JSON.stringify(maxMintableSupply)} \
            ${JSON.stringify(globalWalletLimit)} \
            ${mintCurrency} \
            ${fundReceiver} \
            '${stagesData}' \
            ${royaltyReceiver} \
            ${royaltyFee} \
            ${passwordOption} \
            ${zksyncFlag} \
            --rpc-url "${rpcUrl}" \
            --json
        `;

    // Execute the command and capture the output
    const output = executeCommand(command);
    const txnData: TransactionData = JSON.parse(output);

    // Print the transaction hash
    printTransactionHash(txnData.transactionHash, chainId);

    console.log('Contract setup completed.');
  } catch (error: any) {
    console.error('Error setting up contract:', error.message);
    throw new Error('Failed to set up contract.');
  }
};
