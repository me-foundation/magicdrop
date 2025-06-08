import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import { cleanWhitelist, cleanVariableWalletLimit } from './helper';

export async function generateMerkleRoot(
  path?: string,
  isVariableWalletLimit: boolean = false,
): Promise<string> {
  if (!path) {
    return ethers.utils.hexZeroPad('0x', 32);
  }

  const leaves = isVariableWalletLimit
    ? await getVariableWalletLimitLeaves(path)
    : await getWhitelistLeaves(path);

  const mt = new MerkleTree(leaves, ethers.utils.keccak256, {
    sortPairs: true,
    hashLeaves: false,
  });
  return mt.getHexRoot();
}

async function getWhitelistLeaves(path: string): Promise<string[]> {
  const filteredSet = await cleanWhitelist(path, true);
  return Array.from(filteredSet.values()).map((address: string) =>
    ethers.utils.solidityKeccak256(
      ['address', 'uint32'],
      [ethers.utils.getAddress(address), 0],
    ),
  );
}

async function getVariableWalletLimitLeaves(path: string): Promise<string[]> {
  const filteredMap = await cleanVariableWalletLimit(path, true);
  return Array.from(filteredMap.entries()).map(([address, limit]) =>
    ethers.utils.solidityKeccak256(['address', 'uint32'], [address, limit]),
  );
}

export async function generateMerkleRootCLI() {
  const path = process.argv[2];
  const isVariableWalletLimit = process.argv[3] === 'true';

  if (!path) {
    throw new Error('Please provide a path to the whitelist file');
  }

  try {
    const merkleRoot = await generateMerkleRoot(path, isVariableWalletLimit);
    console.log('Merkle Root:', merkleRoot);
  } catch (error) {
    throw new Error(`Error generating Merkle root: ${error}`);
  }
}

if (require.main === module) {
  generateMerkleRootCLI();
}
