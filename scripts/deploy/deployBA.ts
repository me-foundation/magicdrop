// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

import { confirm } from '@inquirer/prompts';
import { ContractDetails } from '../common/constants';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { estimateGas } from '../utils/helper';

interface IDeployParams {
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  globalwalletlimit: string;
  cosigner: string;
  mincontributioninwei: number;
  auctionstarttime: string;
  auctionendtime: string;
  fundReceiver: string;
}

export const deployBA = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const contractName = ContractDetails.BucketAuction.name;

  console.log(
    `Going to deploy ${contractName} with params`,
    JSON.stringify(args, null, 2),
  );

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
    args.fundReceiver,
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

  await estimateGas(hre, contractFactory.getDeployTransaction(...params));

  if (!(await confirm({ message: 'Continue to deploy?' }))) return;

  const contract = await contractFactory.deploy(...params);
  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
};
