import fs from 'fs';
import { isAddress } from 'ethers/lib/utils';
import { BigNumber, ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';

type Stage = {
  price: number;
  mintFee: number;
  walletLimit: number;
  whitelistPath?: string;
  maxStageSupply: number;
  startDate: string;
  endDate: string;
};

type Stage1155 = {
  price: number[];
  mintFee: number[];
  walletLimit: number[];
  whitelistPath?: string[];
  maxStageSupply: number[];
  startDate: string;
  endDate: string;
};

type WhitelistEntry = {
  address: string;
  limit?: number;
};

const parseWhitelistFile = (filePath: string): string[] => {
  try {
    const content = fs.readFileSync(filePath, 'utf-8');
    return content
      .split('\n')
      .map((line) => line.trim())
      .filter((line) => line.length > 0);
  } catch (error: any) {
    throw new Error(`Failed to read whitelist file: ${error.message}`);
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
  // Determine the format based on the first entry
  // If it contains a comma, we expect all entries to have a limit
  const firstEntry = entries[0];
  const isVariableWalletLimit = firstEntry.includes(',');
  const invalidEntries: string[] = [];
  const cleanedEntries: WhitelistEntry[] = [];

  for (const entry of entries) {
    // Split entry into parts and clean whitespace
    const parts = entry.split(',').map((x) => x.trim());
    const [address] = parts;

    // Check if entry matches expected format (address only OR address,limit)
    if (parts.length !== (isVariableWalletLimit ? 2 : 1)) {
      invalidEntries.push(entry);
      continue;
    }

    // Validate the Ethereum address format
    if (!isAddress(address)) {
      invalidEntries.push(entry);
      continue;
    }

    // Handle entries with wallet limits
    if (isVariableWalletLimit) {
      const limitStr = parts[1];
      // Check if limit exists
      if (!limitStr) {
        invalidEntries.push(entry);
        continue;
      }

      // Parse and validate the limit value
      const limit = parseInt(limitStr);
      if (isNaN(limit) || limit <= 0) {
        invalidEntries.push(entry);
        continue;
      }

      cleanedEntries.push({ address, limit });
    } else {
      // Handle entries without wallet limits
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
  const isVariableWalletLimit = whitelistEntries[0].limit !== undefined;
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
      return ethers.utils.solidityKeccak256(['address'], [entry.address]);
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
  return (
    isNumberOrString(stage.price) &&
    isNumberOrString(stage.mintFee) &&
    isNumberOrString(stage.walletLimit) &&
    (isNumberOrString(stage.maxStageSupply) ||
      stage.maxStageSupply === undefined) &&
    typeof stage.startDate === 'string' &&
    typeof stage.endDate === 'string' &&
    (typeof stage.whitelistPath === 'string' ||
      stage.whitelistPath === undefined)
  );
}

function isStage1155(stage: any): stage is Stage1155 {
  return (
    Array.isArray(stage.price) &&
    stage.price.every(isNumberOrString) &&
    Array.isArray(stage.mintFee) &&
    stage.mintFee.every(isNumberOrString) &&
    Array.isArray(stage.walletLimit) &&
    stage.walletLimit.every(isNumberOrString) &&
    ((Array.isArray(stage.maxStageSupply) &&
      stage.maxStageSupply.every(isNumberOrString)) ||
      stage.maxStageSupply === undefined) &&
    typeof stage.startDate === 'string' &&
    typeof stage.endDate === 'string' &&
    ((Array.isArray(stage.whitelistPath) &&
      stage.whitelistPath.every((value: any) => typeof value === 'string')) ||
      stage.whitelistPath === undefined)
  );
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
const processERC1155Stage = (stage: Stage1155, stageIdx: number): string => {
  verifyStage1155ArrayLengths(stage);
  const merkleRoots = generateERC1155MerkleRoots(stage, stageIdx);
  const maxStageSupply =
    stage.maxStageSupply ?? new Array(merkleRoots.length).fill(0);

  return formatStageData([
    `[${stage.price.map((p) => ethers.utils.parseEther(p.toString())).join(',')}]`,
    `[${stage.mintFee.map((f) => ethers.utils.parseEther(f.toString())).join(',')}]`,
    `[${stage.walletLimit.join(',')}]`,
    `[${merkleRoots.join(',')}]`,
    `[${maxStageSupply.join(',')}]`,
    new Date(stage.startDate).getTime() / 1000,
    new Date(stage.endDate).getTime() / 1000,
  ]);
};

/**
 * Generates merkle roots for an ERC1155 stage
 * @param stage - The Stage1155 object containing whitelist paths
 * @param stageIdx - The index of the stage
 * @returns Array of merkle root strings
 */
const generateERC1155MerkleRoots = (
  stage: Stage1155,
  stageIdx: number,
): string[] => {
  if (!stage.whitelistPath) {
    return new Array(stage.price.length).fill(
      ethers.utils.hexZeroPad('0x', 32),
    );
  }

  return stage.whitelistPath.map((whitelistPath) => {
    if (whitelistPath === '') {
      return ethers.utils.hexZeroPad('0x', 32);
    }

    const rawWhitelist = parseWhitelistFile(whitelistPath);
    const cleanedWhitelist = cleanWhitelistData(rawWhitelist, stageIdx);
    console.log(
      `Processed whitelist for stage ${stageIdx} with ${cleanedWhitelist.length} entries`,
    );
    return generateMerkleRoot(cleanedWhitelist);
  });
};

/**
 * Processes a single ERC721 stage and returns its formatted data
 * @param stage - The Stage object to process
 * @param stageIdx - The index of the stage in the stages array
 * @returns Formatted stage data string
 */
const processERC721Stage = (stage: Stage, stageIdx: number): string => {
  const merkleRoot = generateERC721MerkleRoot(stage, stageIdx);

  return formatStageData([
    ethers.utils.parseEther(stage.price.toString()),
    ethers.utils.parseEther(stage.mintFee.toString()),
    stage.walletLimit,
    merkleRoot,
    stage.maxStageSupply ?? 0,
    new Date(stage.startDate).getTime() / 1000,
    new Date(stage.endDate).getTime() / 1000,
  ]);
};

/**
 * Generates merkle root for an ERC721 stage
 * @param stage - The Stage object containing whitelist path
 * @param stageIdx - The index of the stage
 * @returns Merkle root string
 */
const generateERC721MerkleRoot = (stage: Stage, stageIdx: number): string => {
  if (!stage.whitelistPath) {
    return ethers.utils.hexZeroPad('0x', 32);
  }

  const rawWhitelist = parseWhitelistFile(stage.whitelistPath);
  const cleanedWhitelist = cleanWhitelistData(rawWhitelist, stageIdx);
  console.log(
    `Processed whitelist for stage ${stageIdx} with ${cleanedWhitelist.length} entries`,
  );
  return generateMerkleRoot(cleanedWhitelist);
};

/**
 * Formats stage data into a string representation
 * @param data - Array of values to format
 * @returns Formatted string wrapped in parentheses
 */
const formatStageData = (data: (string | number | BigNumber)[]): string => {
  return '(' + data.join(',') + ')';
};

const getStagesData = async () => {
  const { stagesFilePath, outputFilePath, isERC1155 } = parseAndValidateArgs();
  const rawStages = loadAndValidateStages(stagesFilePath, isERC1155);
  const typedStages = isERC1155
    ? (rawStages as Stage1155[])
    : (rawStages as Stage[]);

  try {
    const stagesData = typedStages.map((stage, stageIdx) =>
      isERC1155 && isStage1155(stage)
        ? processERC1155Stage(stage, stageIdx)
        : isStage(stage)
          ? processERC721Stage(stage, stageIdx)
          : '',
    );

    const stagesInput = '[' + stagesData.join(',') + ']';
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
  const outputFilePath = process.argv[3];
  const tokenStandard = process.argv[4];

  if (!stagesFilePath) {
    console.error('Please provide a path to the whitelist file');
    process.exit(1);
  }

  return {
    stagesFilePath,
    outputFilePath,
    isERC1155: tokenStandard === 'ERC1155',
  };
};

/**
 * Loads and validates stages from a JSON file
 * @param stagesFilePath - Path to the stages JSON file
 * @param isERC1155 - Whether the stages are for ERC1155
 * @returns Validated stages array
 */
const loadAndValidateStages = (stagesFilePath: string, isERC1155: boolean) => {
  const rawStages = JSON.parse(fs.readFileSync(stagesFilePath, 'utf-8'));

  if (!Array.isArray(rawStages)) {
    throw new Error('Stages must be an array');
  }

  if (isERC1155) {
    if (!rawStages.every(isStage1155)) {
      throw new Error(
        'Invalid stage format for ERC1155. Each stage must include arrays for price, mintFee, walletLimit',
      );
    }
  } else {
    if (!rawStages.every(isStage)) {
      throw new Error(
        'Invalid stage format for ERC721. Each stage must include single values for price, mintFee, walletLimit',
      );
    }
  }

  return rawStages;
};

if (require.main === module) {
  getStagesData()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Error:', error);
      process.exit(1);
    });
}
