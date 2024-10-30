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

const getStagesData = async () => {
  const stagesFilePath = process.argv[2];
  const outputFilePath = process.argv[3] ?? './stagesInput.tmp';

  if (!stagesFilePath) {
    console.error('Please provide a path to the whitelist file');
    process.exit(1);
  }

  const stages: Stage[] = JSON.parse(fs.readFileSync(stagesFilePath, 'utf-8'));
  const stagesData: string[] = [];

  try {
    for (const [stageIdx, stage] of stages.entries()) {
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

      // Following the Stage struct definition in the contract
      // (uint80,uint80,uint32,bytes32,uint24,uint256,uint256)[]
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

    const stagesInput = '[' + stagesData.join(',') + ']';
    fs.writeFileSync(outputFilePath, stagesInput, 'utf-8');
    console.log(`Stages input written to temp file: ${outputFilePath}`);
  } catch (error) {
    console.error('Error processing whitelist:', error);
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
