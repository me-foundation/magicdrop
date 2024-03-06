import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { MerkleTree } from 'merkletreejs';
import fs from 'fs';
import { ContractDetails } from './common/constants';
import { estimateGas } from './utils/helper';
import { Overrides } from 'ethers';

export interface ISetStagesParams {
  stages: string;
  contract: string;
  gaspricegwei?: number;
  gaslimit?: number;
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

  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = ethers.BigNumber.from(args.gaslimit);
  }
  const merkleRoots = await Promise.all(
    stagesConfig.map((stage) => {
      if (!stage.whitelistPath) {
        return ethers.utils.hexZeroPad('0x', 32);
      }
      const whitelist = JSON.parse(
        fs.readFileSync(stage.whitelistPath, 'utf-8'),
      );

      // Clean up whitelist
      const filteredWhitelist=  whitelist.filter((address: string) => ethers.utils.isAddress(address));
      console.log(`Filtered whitelist: ${filteredWhitelist.length} addresses. ${whitelist.length - filteredWhitelist.length} invalid addresses removed.`);
      const invalidWhitelist=  whitelist.filter((address: string) => !ethers.utils.isAddress(address));
      console.log(`❌ Invalid whitelist: ${invalidWhitelist.length} addresses.\r\n${invalidWhitelist.join(', \r\n')}`);

      if (invalidWhitelist.length > 0) {
        console.log(`🔄 🚨 updating whitelist file: ${stage.whitelistPath}`);
        fs.writeFileSync(stage.whitelistPath, JSON.stringify(filteredWhitelist, null, 2))
      }

      const mt = new MerkleTree(
        filteredWhitelist.map(ethers.utils.getAddress),
        ethers.utils.keccak256,
        {
          sortPairs: true,
          hashLeaves: true,
        },
      );
      return mt.getHexRoot();
    }),
  );

  const stages = stagesConfig.map((s, i) => ({
    price: ethers.utils.parseEther(s.price),
    maxStageSupply: s.maxSupply ?? 0,
    walletLimit: s.walletLimit ?? 0,
    merkleRoot: merkleRoots[i],
    startTimeUnixSeconds: Math.floor(new Date(s.startDate).getTime() / 1000),
    endTimeUnixSeconds: Math.floor(new Date(s.endDate).getTime() / 1000),
  }));

  console.log(
    `Stage params: `,
    JSON.stringify(
      stages.map(stage => hre.ethers.BigNumber.isBigNumber(stage)? stage.toString() : stage)
    ),
  );

  const tx = await contract.populateTransaction.setStages(stages);
  if (!(await estimateGas(hre, tx, overrides))) return;

  if (!await confirm({ message: 'Continue to set stages?' })) return;

  const submittedTx = await contract.setStages(stages, overrides);

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log('Stages set');

  for (let i = 0; i < stagesConfig.length; i++) {
    const [stage] = await contract.getStageInfo(i);
    console.log(`Stage ${i} info: ${stage}`);
  }
};
