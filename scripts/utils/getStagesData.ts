import fs from 'fs';
import { isAddress } from 'ethers/lib/utils';
import { BigNumber, ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import path from 'path';

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

// const parseWhitelistFile = (filePath: string): string[] => {
//   try {
//     const content = fs.readFileSync(filePath, 'utf-8');
//     return content
//       .split('\n')
//       .map((line) => line.trim())
//       .filter((line) => line.length > 0);
//   } catch (error: any) {
//     throw new Error(`Failed to read whitelist file: ${error.message}`);
//   }
// };

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
      fs.writeFileSync(invalidEntriesPath, invalidEntries.join('\n'), 'utf-8');
      console.log(`Invalid entries have been written to ${invalidEntriesPath}`);
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
      return ethers.utils.solidityKeccak256(
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
      return ethers.utils.solidityKeccak256(
        ['address', 'uint32'],
        [entry.address, 0],
      );
    });
  }

  // Create Merkle tree with specific options:
  // - sortPairs: true ensures deterministic results regardless of input order
  // - hashLeaves: false because we've already hashed our leaves
  const mt = new MerkleTree(leaves, ethers.utils.keccak256, {
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
      `Array length mismatch in Stage1155. All arrays must have the same length. ` +
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
  web3StorageKey: string,
): Promise<string> => {
  verifyStage1155ArrayLengths(stage);
  const merkleRoots = await generateERC1155MerkleRoots(
    stage,
    stageIdx,
    outputFileDir,
    web3StorageKey,
  );
  const maxStageSupply =
    stage.maxStageSupply ?? new Array(merkleRoots.length).fill(0);

  return formatStageData([
    `[${stage.price.map((p) => ethers.utils.parseEther(p.toString())).join(',')}]`,
    `[${stage.mintFee.map((f) => ethers.utils.parseEther(f.toString())).join(',')}]`,
    `[${stage.walletLimit.join(',')}]`,
    `[${merkleRoots.join(',')}]`,
    `[${maxStageSupply.join(',')}]`,
    new Date(stage.startTime).getTime() / 1000,
    new Date(stage.endTime).getTime() / 1000,
  ]);
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
  web3StorageKey: string,
): Promise<string[]> => {
  if (!stage.whitelistPath) {
    return new Array(stage.price.length).fill(
      ethers.utils.hexZeroPad('0x', 32),
    );
  }

  return Promise.all(
    stage.whitelistPath.map(async (whitelistPath) => {
      if (whitelistPath === '') {
        return ethers.utils.hexZeroPad('0x', 32);
      }

      const rawWhitelist = parseWhitelistFile(whitelistPath);
      const cleanedWhitelist = cleanWhitelistData(rawWhitelist, stageIdx);
      const fs = require('fs');
      const path = require('path');
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
      return generateMerkleRoot(cleanedWhitelist);
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
  web3StorageKey: string,
): Promise<string> => {
  const merkleRoot = await generateERC721MerkleRoot(
    stage,
    stageIdx,
    outputFileDir,
    web3StorageKey,
  );

  return formatStageData([
    ethers.utils.parseEther(stage.price.toString()),
    ethers.utils.parseEther(stage.mintFee.toString()),
    stage.walletLimit,
    merkleRoot,
    stage.maxStageSupply ?? 0,
    new Date(stage.startTime).getTime() / 1000,
    new Date(stage.endTime).getTime() / 1000,
  ]);
};

/**
 * Generates merkle root for an ERC721 stage
 * @param stage - The Stage object containing whitelist path
 * @param stageIdx - The index of the stage
 * @returns Merkle root string
 */
const generateERC721MerkleRoot = async (
  stage: Stage,
  stageIdx: number,
  outputFileDir: string,
  web3StorageKey: string,
): Promise<string> => {
  if (!stage.whitelistPath) {
    return Promise.resolve(ethers.utils.hexZeroPad('0x', 32));
  }

  const rawWhitelist = parseWhitelistFile(stage.whitelistPath);
  const cleanedWhitelist = cleanWhitelistData(rawWhitelist, stageIdx);
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

  return Promise.resolve(generateMerkleRoot(cleanedWhitelist));
};

/**
 * Formats stage data into a string representation
 * @param data - Array of values to format
 * @returns Formatted string wrapped in parentheses
 */
const formatStageData = (data: (string | number | BigNumber)[]): string => {
  return '(' + data.join(',') + ')';
};

const main = async () => {
  const {
    stagesFilePath,
    outputFileDir,
    isERC1155,
    web3StorageKey,
    stagesJson,
  } = parseAndValidateArgs();

  await getStagesData(
    stagesFilePath,
    isERC1155,
    outputFileDir,
    web3StorageKey,
    stagesJson,
  );
};

const getStagesData = async (
  stagesFilePath: string | undefined,
  isERC1155: boolean,
  outputFileDir: string,
  web3StorageKey: string,
  stagesJson?: string,
) => {
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
      typedStages.map(async (stage, stageIdx) =>
        isERC1155 && isStage1155(stage)
          ? processERC1155Stage(stage, stageIdx, outputFileDir, web3StorageKey)
          : isStage(stage)
            ? processERC721Stage(stage, stageIdx, outputFileDir, web3StorageKey)
            : '',
      ),
    );

    const stagesInput = '[' + stagesData.join(',') + ']';
    const outputFilePath = path.join(outputFileDir, `stagesInput.tmp`);
    fs.writeFileSync(outputFilePath, stagesInput, 'utf-8');
    console.log(`Stages input written to temp file: ${outputFilePath}`);
  } catch (error) {
    console.error('Error processing stages:', error);
    process.exit(1);
  }
};

/**
 * Parses and validates command line arguments
 * @returns Object containing validated arguments
 */
const parseAndValidateArgs = () => {
  const stagesFilePath = process.argv[2];
  const stagesJson = process.argv[3];
  const outputFileDir = process.argv[4];
  const tokenStandard = process.argv[5];
  const web3StorageKey = process.argv[6];

  if (!stagesFilePath && !stagesJson) {
    console.error(
      'Please provide either a path to the stages file or a JSON string of stages',
    );
    process.exit(1);
  }

  return {
    stagesFilePath,
    outputFileDir,
    isERC1155: tokenStandard === 'ERC1155',
    web3StorageKey,
    stagesJson,
  };
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

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Error:', error);
      process.exit(1);
    });
}
