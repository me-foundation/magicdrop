import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { MerkleTree } from 'merkletreejs';
import fs from 'fs';

export interface ISetStagesParams {
  stages: string;
  contract: string;
}

interface StageConfig {
  price: string;
  startDate: number;
  endDate: number;
  walletLimit?: number;
  maxSupply?: number;
  whitelistPath?: string;
}

export const setStages = async (
  args: ISetStagesParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const stagesConfig = JSON.parse(
    fs.readFileSync(args.stages, 'utf-8'),
  ) as StageConfig[];
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const merkleRoots = await Promise.all(
    stagesConfig.map((stage) => {
      if (!stage.whitelistPath) {
        return ethers.utils.hexZeroPad('0x', 32);
      }
      const whitelist = JSON.parse(
        fs.readFileSync(stage.whitelistPath, 'utf-8'),
      );
      const mt = new MerkleTree(
        whitelist.map(ethers.utils.getAddress),
        ethers.utils.keccak256,
        {
          sortPairs: true,
          hashLeaves: true,
        },
      );
      return mt.getHexRoot();
    }),
  );
  const tx = await contract.setStages(
    stagesConfig.map((s, i) => ({
      price: ethers.utils.parseEther(s.price),
      maxStageSupply: s.maxSupply ?? 0,
      walletLimit: s.walletLimit ?? 0,
      merkleRoot: merkleRoots[i],
      startTimeUnixSeconds: Math.floor(new Date(s.startDate).getTime() / 1000),
      endTimeUnixSeconds: Math.floor(new Date(s.endDate).getTime() / 1000),
    })),
    { gasLimit: 500_000 },
  );
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set stages:', tx.hash);

  for (let i = 0; i < stagesConfig.length; i++) {
    const [stage] = await contract.getStageInfo(i);
    console.log(`Stage ${i} info: ${stage}`);
  }
};
