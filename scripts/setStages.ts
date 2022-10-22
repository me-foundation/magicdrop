import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { MerkleTree } from 'merkletreejs';
import fs from 'fs';
import {
  SaleTypes,
  StageTypes,
  isEquivalent,
  getSaleEnumValueByName,
} from './common/utils';

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
  stageType: string;
  saleType: string;
}

export const setStages = async (
  args: ISetStagesParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const stagesConfig = JSON.parse(
    fs.readFileSync(args.stages, 'utf-8'),
  ) as StageConfig[];
  // Sanity Check
  failIfIssuesFound(stagesConfig);

  const ERC721M = await ethers.getContractFactory(SaleTypes.ERC721M.strVal);
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
      saleType: hre.ethers.BigNumber.from(getSaleEnumValueByName(s.saleType)),
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

const failIfIssuesFound = (stagesConfig: StageConfig[]) => {
  const issuesFound = stagesConfig
    .map((stage, index) => {
      const errorMsg: string[] = [];
      const prefix = `Stage index: ${index}\n   Start date: ${stage.startDate}.\n`;
      if (
        !stage.whitelistPath &&
        isEquivalent(StageTypes.WhiteList.strVal, stage.stageType)
      ) {
        errorMsg.push(
          `   -> The stageType is specified as ${StageTypes.WhiteList.strVal} but whitelist property is missing.\n`,
        );
      }
      if (
        stage.whitelistPath &&
        !isEquivalent(StageTypes.WhiteList.strVal, stage.stageType)
      ) {
        errorMsg.push(
          `   -> The whitelist was specified but stageType is not declared as ${StageTypes.WhiteList.strVal}\n`,
        );
      }

      return [prefix, errorMsg];
    })
    .filter(([prefix, errorMsg]) => {
      return errorMsg.length > 0;
    });

  if (issuesFound.length > 0) {
    const compiledErrorMsg = issuesFound.reduce(
      (previousMsgArray, currentMsgArray, index) => {
        previousMsgArray.push(`${index + 1}. ${currentMsgArray[0]}`);
        return previousMsgArray.concat(currentMsgArray[1]);
      },
      [],
    );

    const errPrefix =
      '\n!!!This task was FAILED! Please check the error message below!\nProblems found in the stages listed below.\n';

    throw new Error(`${errPrefix}${compiledErrorMsg.join('')}`);
  }
};
