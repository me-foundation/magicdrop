import fs from 'fs';
import { isAddress } from 'ethers/lib/utils';
import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import os from 'os';
import path from 'path';

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

const cleanWhitelistData = (
  entries: string[],
  stageIdx: number,
): WhitelistEntry[] => {
  // First entry determines the expected format
  const firstEntry = entries[0];
  const isVariableWalletLimit = firstEntry.includes(',');
  const invalidEntries: string[] = [];
  const cleanedEntries: WhitelistEntry[] = [];

  for (const entry of entries) {
    const parts = entry.split(',').map((x) => x.trim());
    const [address] = parts;

    // Validate format consistency
    if (parts.length !== (isVariableWalletLimit ? 2 : 1)) {
      invalidEntries.push(entry);
      continue;
    }

    if (!isAddress(address)) {
      invalidEntries.push(entry);
      continue;
    }

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

const generateMerkleRoot = (whitelistEntries: WhitelistEntry[]) => {
  const isVariableWalletLimit = whitelistEntries[0].limit !== undefined;
  let leaves: string[] = [];

  if (isVariableWalletLimit) {
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
    leaves = whitelistEntries.map((entry) => {
      return ethers.utils.solidityKeccak256(['address'], [entry.address]);
    });
  }

  const mt = new MerkleTree(leaves, ethers.utils.keccak256, {
    sortPairs: true,
    hashLeaves: false,
  });

  return mt.getHexRoot();
};

function isStage(stage: any): stage is Stage {
  return (
    typeof stage.price === 'number' &&
    typeof stage.mintFee === 'number' &&
    typeof stage.walletLimit === 'number' &&
    (typeof stage.maxStageSupply === 'number' ||
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
    Array.isArray(stage.mintFee) &&
    Array.isArray(stage.walletLimit) &&
    (Array.isArray(stage.maxStageSupply) ||
      stage.maxStageSupply === undefined) &&
    typeof stage.startDate === 'string' &&
    typeof stage.endDate === 'string' &&
    (Array.isArray(stage.whitelistPath) || stage.whitelistPath === undefined)
  );
}

function verifyStage1155ArrayLengths(stage: Stage1155): void {
  const requiredArrayFields = [
    { name: 'price', array: stage.price },
    { name: 'mintFee', array: stage.mintFee },
    { name: 'walletLimit', array: stage.walletLimit },
  ];

  const lengths = requiredArrayFields.map((field) => ({
    name: field.name,
    length: field.array.length,
  }));

  const firstLength = lengths[0].length;
  const mismatchedFields = lengths
    .filter((field) => field.length !== firstLength)
    .map((field) => field.name);

  // Check whitelistPath length only if it exists
  if (stage.whitelistPath && stage.whitelistPath.length !== firstLength) {
    mismatchedFields.push('whitelistPath');
  }

  // Check maxStageSupply length only if it exists
  if (stage.maxStageSupply && stage.maxStageSupply.length !== firstLength) {
    mismatchedFields.push('maxStageSupply');
  }

  if (mismatchedFields.length > 0) {
    throw new Error(
      `Array length mismatch in Stage1155. All arrays must have the same length. ` +
        `Expected length: ${firstLength}, but got different lengths for: ${mismatchedFields.join(', ')}`,
    );
  }
}

const getStagesData = async () => {
  const stagesFilePath = process.argv[2];
  const outputFilePath = process.argv[3];
  const tokenStandard = process.argv[4];

  if (!stagesFilePath) {
    console.error('Please provide a path to the whitelist file');
    process.exit(1);
  }

  const isERC1155 = tokenStandard === 'ERC1155';
  const rawStages = JSON.parse(fs.readFileSync(stagesFilePath, 'utf-8'));

  // Validate stages based on token standard
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

  // Now TypeScript knows the correct type for rawStages
  const typedStages = isERC1155
    ? (rawStages as Stage1155[])
    : (rawStages as Stage[]);
  const stagesData: string[] = [];

  try {
    for (const [stageIdx, stage] of typedStages.entries()) {
      if (isERC1155 && isStage1155(stage)) {
        verifyStage1155ArrayLengths(stage);

        let merkleRoots: string[] = [];
        if (stage.whitelistPath) {
          for (const whitelistPath of stage.whitelistPath) {
            // if the whitelistPath is empty, we assume this token doesnt have a whitelist
            // even though some others might
            if (whitelistPath === '') {
              merkleRoots.push(ethers.utils.hexZeroPad('0x', 32));
              continue;
            }

            const rawWhitelist = parseWhitelistFile(whitelistPath);
            const cleanedWhitelist = cleanWhitelistData(rawWhitelist, stageIdx);
            console.log(
              `Processed whitelist for stage ${stageIdx} with ${cleanedWhitelist.length} entries`,
            );
            merkleRoots.push(generateMerkleRoot(cleanedWhitelist));
          }
        } else {
          // If no whitelist paths are provided, we need to create a merkle root for each token ID
          // We have verified that all arrays are the same length, so we can use the length of one of them
          merkleRoots = new Array(stage.price.length).fill(
            ethers.utils.hexZeroPad('0x', 32),
          );
        }

        const maxStageSupply =
          stage.maxStageSupply ?? new Array(merkleRoots.length).fill(0);

        const stageData =
          '(' +
          [
            `[${stage.price.map((p) => ethers.utils.parseEther(p.toString())).join(',')}]`,
            `[${stage.mintFee.map((f) => ethers.utils.parseEther(f.toString())).join(',')}]`,
            `[${stage.walletLimit.join(',')}]`,
            `[${merkleRoots.join(',')}]`,
            `[${maxStageSupply.join(',')}]`,
            new Date(stage.startDate).getTime() / 1000,
            new Date(stage.endDate).getTime() / 1000,
          ].join(',') +
          ')';

        stagesData.push(stageData);
      } else if (!isERC1155 && isStage(stage)) {
        let merkleRoot: string | undefined;
        if (stage.whitelistPath) {
          const rawWhitelist = parseWhitelistFile(stage.whitelistPath);
          const cleanedWhitelist = cleanWhitelistData(rawWhitelist, stageIdx);
          console.log(
            `Processed whitelist for stage ${stageIdx} with ${cleanedWhitelist.length} entries`,
          );
          merkleRoot = generateMerkleRoot(cleanedWhitelist);
        } else {
          merkleRoot = ethers.utils.hexZeroPad('0x', 32);
        }

        const stageData =
          '(' +
          [
            ethers.utils.parseEther(stage.price.toString()),
            ethers.utils.parseEther(stage.mintFee.toString()),
            stage.walletLimit,
            merkleRoot,
            stage.maxStageSupply ?? 0,
            new Date(stage.startDate).getTime() / 1000,
            new Date(stage.endDate).getTime() / 1000,
          ].join(',') +
          ')';
        stagesData.push(stageData);
      }
    }

    const stagesInput = '[' + stagesData.join(',') + ']';
    fs.writeFileSync(outputFilePath, stagesInput, 'utf-8');
    console.log(`Stages input written to temp file: ${outputFilePath}`);
  } catch (error) {
    console.error('Error processing stages:', error);
    process.exit(1);
  }
};

if (require.main === module) {
  getStagesData()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error('Error:', error);
      process.exit(1);
    });
}
