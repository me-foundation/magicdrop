import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { MerkleTree } from 'merkletreejs';
import fs from 'fs';
import { ContractDetails } from '../common/constants';
import { estimateGas } from '../utils/helper';
import { Overrides } from 'ethers';
import { generateMerkleRoot } from '../utils/generateMerkleRoot';

export interface ISetStagesParams {
  stages: string;
  contract: string;
  gaspricegwei?: number;
  gaslimit?: number;
}

interface StageConfig {
  price: string;
  mintFee?: string;
  startDate: number;
  endDate: number;
  walletLimit?: number;
  maxSupply?: number;
  whitelistPath?: string;
  variableWalletLimitPath?: string;
}

export const setStages = async (
  args: ISetStagesParams,
  hre: HardhatRuntimeEnvironment,
) => {
  console.log('args', args);
  const { ethers } = hre;
  const stagesConfig = JSON.parse(
    fs.readFileSync(args.stages, 'utf-8'),
  ) as StageConfig[];

  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);

  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = ethers.BigNumber.from(args.gaslimit);
  }

  const merkleRoots = await Promise.all(
    stagesConfig.map(async (stage) => {
      const isVariableWalletLimit = !!stage.variableWalletLimitPath;
      return generateMerkleRoot(
        isVariableWalletLimit
          ? stage.variableWalletLimitPath
          : stage.whitelistPath,
        isVariableWalletLimit,
      );
    }),
  );

  const stages = stagesConfig.map((s, i) => ({
    price: ethers.utils.parseEther(s.price),
    mintFee: s.mintFee ? ethers.utils.parseEther(s.mintFee) : 0,
    maxStageSupply: s.maxSupply ?? 0,
    walletLimit: s.walletLimit ?? 0,
    merkleRoot: merkleRoots[i],
    startTimeUnixSeconds: Math.floor(new Date(s.startDate).getTime() / 1000),
    endTimeUnixSeconds: Math.floor(new Date(s.endDate).getTime() / 1000),
  }));

  console.log(
    `Stage params: `,
    JSON.stringify(
      stages.map((stage) =>
        hre.ethers.BigNumber.isBigNumber(stage) ? stage.toString() : stage,
      ),
    ),
  );

  const tx = await contract.populateTransaction.setStages(stages);
  if (!(await estimateGas(hre, tx, overrides))) return;

  if (!(await confirm({ message: 'Continue to set stages?' }))) return;

  const submittedTx = await contract.setStages(stages, overrides);

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log('Stages set');

  for (let i = 0; i < stagesConfig.length; i++) {
    const [stage] = await contract.getStageInfo(i);
    console.log(`Stage ${i} info: ${stage}`);
  }
};
