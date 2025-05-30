import fs from 'fs';
import { SUPPORTED_CHAINS, TOKEN_STANDARD } from './constants';
import { Collection, ERC1155StageData, ERC721StageData } from './types';
import { showError } from './display';
import { getProjectStore } from './fileUtils';
import { isArrayOfNumbers } from './common';
import { Hex, isAddress, padHex } from 'viem';
import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import path from 'path';

export class EvmPlatform {
  name: string;
  coinSymbol: string;

  constructor(
    name: string,
    coinSymbol: string,
    public chainIdsMap: Map<string, SUPPORTED_CHAINS>,
    public defaultChain: string,
  ) {
    if (!chainIdsMap.has(defaultChain)) {
      throw new Error(
        `The given default chain name ${defaultChain} doesn't exist in the given constructor parameter chainIdsMap`,
      );
    }

    this.name = name;
    this.coinSymbol = coinSymbol;
  }

  isChainIdSupported(chainId: number): boolean {
    return (
      Array.from(this.chainIdsMap.values()).find((id) => id === chainId) !==
      undefined
    );
  }
}

/**
 * Validates the config loaded from the config file or CLI
 * @param platform the evm platform
 * @param config collection config
 * @param setupContract flag to setup contract after contract deployment
 * @returns
 */
export const validateConfig = (
  platform: EvmPlatform,
  config: Collection,
  setupContract?: boolean,
  totalTokens?: number,
): boolean => {
  const errors: string[] = [];

  if (
    !config.chainId ||
    typeof config.chainId !== 'number' ||
    !platform.isChainIdSupported(config.chainId)
  ) {
    errors.push(
      `Invalid or missing chainId. Try any of ${Array.from(platform.chainIdsMap.values())}`,
    );
  }

  if (
    !config.tokenStandard ||
    ![TOKEN_STANDARD.ERC721, TOKEN_STANDARD.ERC1155].includes(
      config.tokenStandard as any,
    )
  ) {
    errors.push(
      `Invalid or missing tokenStandard. Must be "${TOKEN_STANDARD.ERC721}" or "${TOKEN_STANDARD.ERC1155}".`,
    );
  }

  if (!config.name || typeof config.name !== 'string') {
    errors.push(
      'Invalid or missing collectionName.  Enter the `name` in the config file.',
    );
  }

  if (!config.symbol || typeof config.symbol !== 'string') {
    errors.push(
      'Invalid or missing symbol. Enter the `symbol` in the config file.',
    );
  }

  if (!config.cosigner || !isAddress(config.cosigner)) {
    errors.push(
      'Invalid or missing cosigner address. Enter the `cosigner` in the config file.',
    );
  }

  if (!config.mintCurrency || !isAddress(config.mintCurrency)) {
    errors.push(
      'Invalid or missing mintCurrency address. It should a number. Enter the `mintCurrency` in the config file.',
    );
  }

  if (!config.mintCurrency || typeof config.mintable !== 'boolean') {
    errors.push(
      'Invalid or missing mintable. It should either be true or false',
    );
  }

  if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
    if (setupContract && isNaN(config.globalWalletLimit)) {
      errors.push(
        'Invalid or missing globalWalletLimit. It should a number. Enter the `globalWalletLimit` in the config file.',
      );
    }

    if (setupContract && isNaN(config.maxMintableSupply)) {
      errors.push('Invalid or missing maxMintableSupply. It should a number.');
    }

    if (typeof config.useERC721C !== 'boolean') {
      errors.push(
        'Invalid or missing useERC721C. It should either be true or false.',
      );
    }

    if (
      setupContract &&
      (!config.tokenUriSuffix || typeof config.tokenUriSuffix !== 'string')
    ) {
      errors.push(
        'Invalid or missing tokenUriSuffix. Enter the `tokenUriSuffix` in the config file.',
      );
    }
  }

  if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
    if (
      setupContract &&
      (!Array.isArray(config.globalWalletLimit) ||
        !isArrayOfNumbers(config.globalWalletLimit))
    ) {
      errors.push(
        'Invalid or missing globalWalletLimit. It should be an array of numbers. Enter the `globalWalletLimit` in the config file.',
      );
    }

    if (
      setupContract &&
      (!Array.isArray(config.maxMintableSupply) ||
        !isArrayOfNumbers(config.maxMintableSupply))
    ) {
      errors.push(
        'Invalid or missing maxMintableSupply. It should be an array of numbers. It should be an array of numbers. Enter the `maxMintableSupply` in the config file.',
      );
    }

    if (totalTokens !== undefined && isNaN(totalTokens)) {
      errors.push(
        'Invalid or missing totalTokens. Pass the --totalTokens flag if you want to setup contract.',
      );
    }
  }

  if (setupContract) {
    if (!config.uri || typeof config.uri !== 'string') {
      errors.push(
        'Invalid or missing uri. Enter the `uri` in the config file.',
      );
    }

    if (!config.fundReceiver || !isAddress(config.fundReceiver)) {
      errors.push(
        'Invalid or missing fundReceiver. Enter the `fundReceiver` in the config file.',
      );
    }

    if (!config.royaltyReceiver || !isAddress(config.royaltyReceiver)) {
      errors.push(
        'Invalid or missing royaltyReceiver. Enter the `royaltyReceiver` in the config file.',
      );
    }

    if (isNaN(config.royaltyFee)) {
      errors.push(
        'Invalid or missing royaltyFee. Enter the `royaltyFee` in the config file.',
      );
    }
  }

  // If there are errors, log them and return false
  if (errors.length > 0) {
    console.error('Configuration validation failed with the following errors:');
    errors.forEach((error) => showError({ text: `- ${error}` }));
    return false;
  }

  // If no errors, return true
  return true;
};

export const init = (
  collectionName: string,
): { store: ReturnType<typeof getProjectStore> } => {
  // Construct collection file path
  const store = getProjectStore(collectionName);

  if (!store.exists) {
    throw new Error(`Collection file not found: ${store.root}`);
  }

  // Load config file via collectionConfigFile
  const config = store.read();

  if (!config) {
    throw new Error('Collection file is empty');
  }

  return { store };
};

type Stage = {
  price: number;
  mintFee: number;
  walletLimit: number;
  whitelistPath?: string;
  maxStageSupply: number;
  startTime: string;
  endTime: string;
};

type Stage1155 = {
  price: number[];
  mintFee: number[];
  walletLimit: number[];
  whitelistPath?: string[];
  maxStageSupply: number[];
  startTime: string;
  endTime: string;
};

type WhitelistEntry = {
  address: string;
  limit?: number;
};

const parseWhitelistFile = (filePath: string): string[] => {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    const jsonData = JSON.parse(content);

    // Handle both array of strings and array of objects formats
    if (!Array.isArray(jsonData)) {
      throw new Error('Whitelist file must contain an array');
    }

    return jsonData;
  } catch (error: any) {
    throw new Error(`Failed to parse whitelist file: ${error.message}`);
  }
};

/**
 * Cleans and validates whitelist entries from a raw input array.
 *
 * @param entries - Array of strings containing whitelist entries. Each entry can be either:
 *                 - A single address (e.g., "0x123...")
 *                 - An address with a mint limit (e.g., "0x123...,5")
 * @param stageIdx - The index of the current stage, used for naming the invalid entries file
 * @param outputFileDir - The directory to write the invalid entries file to
 *
 * @returns An array of WhitelistEntry objects containing validated addresses and optional limits
 *
 * @remarks
 * - The format (with or without limit) is determined by the first entry
 * - Invalid entries are logged to a file named 'invalid_entries_stage_{stageIdx}.txt'
 * - Entries are considered invalid if:
 *   1. They don't match the format of the first entry
 *   2. The address is invalid
 *   3. The limit (if required) is missing or not a positive number
 */
const cleanWhitelistData = (
  entries: string[],
  stageIdx: number,
  outputFileDir: string,
): WhitelistEntry[] => {
  const firstEntry = entries[0];
  const isVariableWalletLimit = firstEntry.includes(',');
  const invalidEntries: string[] = [];
  const cleanedEntries: WhitelistEntry[] = [];

  // Use a Set to track unique addresses
  const seenAddresses = new Set<string>();

  for (const entry of entries) {
    const parts = entry.split(',').map((x) => x.trim());
    const [address] = parts;

    // Skip if we've already seen this address
    if (seenAddresses.has(address.toLowerCase())) {
      invalidEntries.push(`${entry} (duplicate)`);
      continue;
    }

    // Check if entry matches expected format
    if (parts.length !== (isVariableWalletLimit ? 2 : 1)) {
      invalidEntries.push(entry);
      continue;
    }

    // Validate the Ethereum address format
    if (!isAddress(address)) {
      invalidEntries.push(entry);
      continue;
    }

    // Add lowercase address to seen set
    seenAddresses.add(address.toLowerCase());

    // Handle entries with wallet limits
    if (isVariableWalletLimit) {
      const limitStr = parts[1];
      if (!limitStr) {
        invalidEntries.push(entry);
        continue;
      }

      const limit = parseInt(limitStr);
      if (isNaN(limit) || limit <= 0) {
        invalidEntries.push(entry);
        continue;
      }

      cleanedEntries.push({ address, limit });
    } else {
      cleanedEntries.push({ address });
    }
  }

  // If we found any invalid entries, write them to a file for review
  if (invalidEntries.length > 0) {
    const invalidEntriesPath = `invalid_entries_stage_${stageIdx}.txt`;
    try {
      const invalidEntriesFile = path.join(outputFileDir, invalidEntriesPath);
      fs.writeFileSync(invalidEntriesFile, invalidEntries.join('\n'), 'utf-8');
      console.log(`Invalid entries have been written to ${invalidEntriesFile}`);
    } catch (error: any) {
      console.error(
        `Failed to write invalid entries to file: ${error.message}`,
      );
    }
  }

  return cleanedEntries;
};

/**
 * Generates a Merkle root from a list of whitelist entries.
 *
 * @param whitelistEntries - Array of WhitelistEntry objects containing addresses and optional mint limits
 * @returns The hex string representation of the Merkle root
 *
 * @remarks
 * - The function handles two types of whitelists:
 *   1. Simple whitelists (address only)
 *   2. Variable limit whitelists (address + mint limit)
 * - For variable limit whitelists, each leaf is keccak256(address, uint32)
 * - For simple whitelists, each leaf is keccak256(address)
 * - The Merkle tree is constructed with sorted pairs for deterministic results
 */
const generateMerkleRoot = (whitelistEntries: WhitelistEntry[]) => {
  // Determine if this whitelist includes per-address mint limits
  const isVariableWalletLimit = whitelistEntries[0]?.limit !== undefined;
  let leaves: string[] = [];

  if (isVariableWalletLimit) {
    // Generate leaves for whitelist entries with limits
    leaves = whitelistEntries.map((entry) => {
      return ethers.solidityPackedKeccak256(
        ['address', 'uint32'],
        // At this point, limit should be defined, if the whitelist was cleaned.
        // If not, an undefined limit will be hashed to 0 and the user will not be
        // able to mint.
        [entry.address, entry.limit ?? 0],
      );
    });
  } else {
    // Generate leaves for simple whitelist entries (address only)
    leaves = whitelistEntries.map((entry) => {
      return ethers.solidityPackedKeccak256(
        ['address', 'uint32'],
        [entry.address, 0],
      );
    });
  }

  // Create Merkle tree with specific options:
  // - sortPairs: true ensures deterministic results regardless of input order
  // - hashLeaves: false because we've already hashed our leaves
  const mt = new MerkleTree(leaves, ethers.keccak256, {
    sortPairs: true,
    hashLeaves: false,
  });

  return mt.getHexRoot();
};

const isNumberOrString = (value: any) =>
  typeof value === 'string' || typeof value === 'number';

function isStage(stage: any): stage is Stage {
  let isValid = true;

  if (!isNumberOrString(stage.price)) {
    console.error('Invalid price', stage.price);
    isValid = false;
  }

  if (!isNumberOrString(stage.mintFee)) {
    console.error('Invalid mintFee', stage.mintFee);
    isValid = false;
  }

  if (!isNumberOrString(stage.walletLimit)) {
    console.error('Invalid walletLimit', stage.walletLimit);
    isValid = false;
  }

  if (
    !(
      isNumberOrString(stage.maxStageSupply) ||
      stage.maxStageSupply === undefined
    )
  ) {
    console.error('Invalid maxStageSupply', stage.maxStageSupply);
    isValid = false;
  }

  if (typeof stage.startTime !== 'string') {
    console.error('Invalid startTime', stage.startTime);
    isValid = false;
  }

  if (typeof stage.endTime !== 'string') {
    console.error('Invalid endTime', stage.endTime);
    isValid = false;
  }

  if (
    !(
      typeof stage.whitelistPath === 'string' ||
      stage.whitelistPath === undefined
    )
  ) {
    console.error('Invalid whitelistPath', stage.whitelistPath);
    isValid = false;
  }

  return isValid;
}

function isStage1155(stage: any): stage is Stage1155 {
  let isValid = true;

  if (!Array.isArray(stage.price) || !stage.price.every(isNumberOrString)) {
    console.error('Invalid price array', stage.price);
    isValid = false;
  }

  if (!Array.isArray(stage.mintFee) || !stage.mintFee.every(isNumberOrString)) {
    console.error('Invalid mintFee array', stage.mintFee);
    isValid = false;
  }

  if (
    !Array.isArray(stage.walletLimit) ||
    !stage.walletLimit.every(isNumberOrString)
  ) {
    console.error('Invalid walletLimit array', stage.walletLimit);
    isValid = false;
  }

  if (
    !(
      (Array.isArray(stage.maxStageSupply) &&
        stage.maxStageSupply.every(isNumberOrString)) ||
      stage.maxStageSupply === undefined
    )
  ) {
    console.error('Invalid maxStageSupply array', stage.maxStageSupply);
    isValid = false;
  }

  if (typeof stage.startTime !== 'string') {
    console.error('Invalid startTime', stage.startTime);
    isValid = false;
  }

  if (typeof stage.endTime !== 'string') {
    console.error('Invalid endTime', stage.endTime);
    isValid = false;
  }

  if (
    !(
      (Array.isArray(stage.whitelistPath) &&
        stage.whitelistPath.every((value: any) => typeof value === 'string')) ||
      stage.whitelistPath === undefined
    )
  ) {
    console.error('Invalid whitelistPath array', stage.whitelistPath);
    isValid = false;
  }

  return isValid;
}

/**
 * Verifies that all array fields in a Stage1155 object have consistent lengths.
 *
 * @param stage - The Stage1155 object to verify
 * @throws Error if any arrays have inconsistent lengths
 *
 * @remarks
 * - Required arrays (must exist): price, mintFee, walletLimit
 * - Optional arrays: whitelistPath, maxStageSupply
 * - All present arrays must have the same length as they correspond to different
 *   properties for each token ID in the collection
 */
function verifyStage1155ArrayLengths(stage: Stage1155): void {
  // Define required fields that must always be arrays
  const requiredArrayFields = [
    { name: 'price', array: stage.price },
    { name: 'mintFee', array: stage.mintFee },
    { name: 'walletLimit', array: stage.walletLimit },
  ];

  // Map fields to their names and lengths for comparison
  const lengths = requiredArrayFields.map((field) => ({
    name: field.name,
    length: field.array.length,
  }));

  // Use the first array's length as the reference length
  const firstLength = lengths[0].length;

  // Find any required fields that don't match the reference length
  const mismatchedFields = lengths
    .filter((field) => field.length !== firstLength)
    .map((field) => field.name);

  // Check optional arrays only if they exist
  if (stage.whitelistPath && stage.whitelistPath.length !== firstLength) {
    mismatchedFields.push('whitelistPath');
  }
  if (stage.maxStageSupply && stage.maxStageSupply.length !== firstLength) {
    mismatchedFields.push('maxStageSupply');
  }

  // Throw error if any mismatches were found
  if (mismatchedFields.length > 0) {
    throw new Error(
      'Array length mismatch in Stage1155. All arrays must have the same length. ' +
        `Expected length: ${firstLength}, but got different lengths for: ${mismatchedFields.join(', ')}`,
    );
  }
}

/**
 * Processes a single ERC1155 stage and returns its formatted data
 * @param stage - The Stage1155 object to process
 * @param stageIdx - The index of the stage in the stages array
 * @returns Formatted stage data string
 */
const processERC1155Stage = async (
  stage: Stage1155,
  stageIdx: number,
  outputFileDir: string,
): Promise<ERC1155StageData> => {
  verifyStage1155ArrayLengths(stage);
  const merkleRoots = await generateERC1155MerkleRoots(
    stage,
    stageIdx,
    outputFileDir,
  );
  const maxStageSupply =
    stage.maxStageSupply ?? new Array(merkleRoots.length).fill(0);

  return {
    price: stage.price.map((p) => ethers.parseEther(p.toString()).toString()),
    mintFee: stage.mintFee.map((f) =>
      ethers.parseEther(f.toString()).toString(),
    ),
    walletLimit: stage.walletLimit,
    merkleRoot: merkleRoots,
    maxStageSupply,
    startTime: new Date(stage.startTime).getTime() / 1000,
    endTime: new Date(stage.endTime).getTime() / 1000,
  };
};

/**
 * Generates merkle roots for an ERC1155 stage
 * @param stage - The Stage1155 object containing whitelist paths
 * @param stageIdx - The index of the stage
 * @returns Array of merkle root strings
 */
const generateERC1155MerkleRoots = async (
  stage: Stage1155,
  stageIdx: number,
  outputFileDir: string,
): Promise<Hex[]> => {
  if (!stage.whitelistPath) {
    return new Array(stage.price.length).fill(padHex('0x', { size: 32 }));
  }

  return Promise.all(
    stage.whitelistPath.map(async (whitelistPath) => {
      if (whitelistPath === '') {
        return padHex('0x', { size: 32 });
      }

      const rawWhitelist = parseWhitelistFile(whitelistPath);
      const cleanedWhitelist = cleanWhitelistData(
        rawWhitelist,
        stageIdx,
        outputFileDir,
      );
      const outputPath = path.join(
        outputFileDir,
        `cleanedWhitelist_stage_${stageIdx}.json`,
      );
      fs.writeFileSync(
        outputPath,
        JSON.stringify(
          cleanedWhitelist.map((e) =>
            e.limit ? `${e.address},${e.limit}` : e.address,
          ),
          null,
          2,
        ),
      );

      console.log(
        `Processed whitelist for stage ${stageIdx} with ${cleanedWhitelist.length} entries`,
      );
      return generateMerkleRoot(cleanedWhitelist) as Hex;
    }),
  );
};

/**
 * Processes a single ERC721 stage and returns its formatted data
 * @param stage - The Stage object to process
 * @param stageIdx - The index of the stage in the stages array
 * @returns Formatted stage data string
 */
const processERC721Stage = async (
  stage: Stage,
  stageIdx: number,
  outputFileDir: string,
): Promise<ERC721StageData> => {
  const merkleRoot = generateERC721MerkleRoot(stage, stageIdx, outputFileDir);

  const data = {
    price: ethers.parseEther(stage.price.toString()).toString(),
    mintFee: ethers.parseEther(stage.mintFee.toString()).toString(),
    walletLimit: stage.walletLimit,
    merkleRoot,
    maxStageSupply: stage.maxStageSupply ?? 0,
    startTime: new Date(stage.startTime).getTime() / 1000,
    endTime: new Date(stage.endTime).getTime() / 1000,
  };

  return data;
};

/**
 * Generates merkle root for an ERC721 stage
 * @param stage - The Stage object containing whitelist path
 * @param stageIdx - The index of the stage
 * @returns Merkle root string
 */
const generateERC721MerkleRoot = (
  stage: Stage,
  stageIdx: number,
  outputFileDir: string,
): Hex => {
  if (!stage.whitelistPath) {
    return padHex('0x', { size: 32 });
  }

  const rawWhitelist = parseWhitelistFile(stage.whitelistPath);
  const cleanedWhitelist = cleanWhitelistData(
    rawWhitelist,
    stageIdx,
    outputFileDir,
  );
  const outputPath = path.join(
    outputFileDir,
    `cleanedWhitelist_stage_${stageIdx}.json`,
  );
  fs.writeFileSync(
    outputPath,
    JSON.stringify(
      cleanedWhitelist.map((e) =>
        e.limit ? `${e.address},${e.limit}` : e.address,
      ),
      null,
      2,
    ),
  );
  console.log(
    `Processed whitelist for stage ${stageIdx} with ${cleanedWhitelist.length} entries`,
  );

  return generateMerkleRoot(cleanedWhitelist) as Hex;
};

export const getStagesData = async (
  stagesFilePath: string | undefined,
  isERC1155: boolean,
  outputFileDir: string,
  stagesJson?: string,
) => {
  if (!stagesFilePath && !stagesJson) {
    throw new Error(
      'Please provide either a path to the stages file or a JSON string of stages',
    );
  }

  const rawStages = loadAndValidateStages(
    stagesFilePath,
    stagesJson,
    isERC1155,
  );
  const typedStages = isERC1155
    ? (rawStages as Stage1155[])
    : (rawStages as Stage[]);

  try {
    const stagesData = await Promise.all(
      typedStages.map(async (stage, stageIdx) => {
        if (
          (isERC1155 && !isStage1155(stage)) ||
          (!isERC1155 && !isStage(stage))
        ) {
          Promise.reject(
            new Error(
              `Invalid stage format for ${isERC1155 ? 'ERC1155' : 'ERC721'} at index ${stageIdx}. Stage data:\n${JSON.stringify(
                stage,
                null,
                2,
              )}`,
            ),
          );
        }

        return isERC1155
          ? processERC1155Stage(stage as Stage1155, stageIdx, outputFileDir)
          : processERC721Stage(stage as Stage, stageIdx, outputFileDir);
      }),
    );

    return stagesData;
  } catch (error) {
    throw new Error(`Error processing stages: ${error}`);
  }
};

/**
 * Loads and validates stages from a JSON file
 * @param stagesFilePath - Path to the stages JSON file
 * @param isERC1155 - Whether the stages are for ERC1155
 * @returns Validated stages array
 */
const loadAndValidateStages = (
  stagesFilePath: string | undefined,
  stagesJson: string | undefined,
  isERC1155: boolean,
) => {
  let rawStages;

  if (stagesFilePath) {
    rawStages = JSON.parse(fs.readFileSync(stagesFilePath, 'utf-8'));
  } else if (stagesJson) {
    try {
      rawStages = JSON.parse(stagesJson);
    } catch (error) {
      throw new Error(`Failed to parse stages JSON string: ${error}`);
    }
  } else {
    throw new Error('Neither stages file path nor JSON string provided');
  }

  if (!Array.isArray(rawStages)) {
    throw new Error('Stages must be an array');
  }

  if (isERC1155) {
    for (let i = 0; i < rawStages.length; i++) {
      if (!isStage1155(rawStages[i])) {
        throw new Error(
          `Invalid stage format for ERC1155 at index ${i}. Stage data:\n${JSON.stringify(rawStages[i], null, 2)}`,
        );
      }
    }
  } else {
    for (let i = 0; i < rawStages.length; i++) {
      if (!isStage(rawStages[i])) {
        throw new Error(
          `Invalid stage format for ERC721 at index ${i}. Stage data:\n${JSON.stringify(rawStages[i], null, 2)}`,
        );
      }
    }
  }

  return rawStages;
};
