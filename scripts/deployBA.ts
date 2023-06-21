// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

import { confirm } from '@inquirer/prompts';
import { ContractDetails } from './common/constants';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface IDeployParams {
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  globalwalletlimit: string;
  cosigner: string;
  mincontributioninwei: number;
  auctionstarttime: string;
  auctionendtime: string;
  useoperatorfilterer?: boolean;
}

export const deployBA = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // Set the contract name
  let contractName: string;

  if (args.useoperatorfilterer) {
    contractName = ContractDetails.BucketAuctionOperatorFilterer.name;
  } else {
    contractName = ContractDetails.BucketAuction.name;
  }

  console.log(
    `Going to deploy ${contractName} with params`,
    JSON.stringify(args, null, 2),
  );
  const answer = await confirm({ message: 'Continue?', default: false });
  if (!answer) { return; }

  if (args.mincontributioninwei <= 0) {
    throw new Error(
      `The parameter mincontributioninwei should be bigger than 0. Given value: ${args.mincontributioninwei}`,
    );
  }
  const contractFactory = await hre.ethers.getContractFactory(contractName);
  // Set the parameters for the contract constructor
  const params = [
    args.name,
    args.symbol,
    args.tokenurisuffix,
    hre.ethers.BigNumber.from(args.maxsupply),
    hre.ethers.BigNumber.from(args.globalwalletlimit),
    args.cosigner ?? hre.ethers.constants.AddressZero,
    hre.ethers.BigNumber.from(args.mincontributioninwei),
    Math.floor(new Date(args.auctionstarttime).getTime() / 1000),
    Math.floor(new Date(args.auctionendtime).getTime() / 1000),
  ] as const;

  console.log(
    `Constructor params: `,
    JSON.stringify(
      params.map((param) => {
        if (hre.ethers.BigNumber.isBigNumber(param)) {
          return param.toString();
        }
        return param;
      }),
    ),
  );

  const contract = await contractFactory.deploy(...params);
  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
};
