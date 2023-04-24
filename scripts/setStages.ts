import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { MerkleTree } from 'merkletreejs';
import fs from 'fs';
import { ContractDetails } from './common/constants';
import { BigNumberish } from 'ethers';

export interface ISetStagesParams {
  stages: string;
  contract: string;
  gaslimit?: BigNumberish;
  gasprice?: number;
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
  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);
  const gasLimit = args.gaslimit ? args.gaslimit : 500_000;
  const gasPrice = args.gasprice ? args.gasprice * 1e9 : 500 * 1e9;
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
    { gasPrice: gasPrice, gasLimit: gasLimit },
  );
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set stages:', tx.hash);

  for (let i = 0; i < stagesConfig.length; i++) {
    const [stage] = await contract.getStageInfo(i);
    console.log(`Stage ${i} info: ${stage}`);
  }
};
