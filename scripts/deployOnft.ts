// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails, LayerZeroEndpoints } from './common/constants';

export interface IDeployParams {
  ismintingcontract: boolean;
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  globalwalletlimit: string;
  cosigner?: string;
  timestampexpiryseconds?: number;
  mingastostore: string;
}

export const deployOnft = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {

  let contractName;
  let deployParams;

  if (args.ismintingcontract) {
    contractName = ContractDetails.ERC721MOnft.name;
    deployParams = [
      args.name,
      args.symbol,
      args.tokenurisuffix,
      hre.ethers.BigNumber.from(args.maxsupply),
      hre.ethers.BigNumber.from(args.globalwalletlimit),
      args.cosigner ?? hre.ethers.constants.AddressZero,
      args.timestampexpiryseconds ?? 300,
      hre.ethers.BigNumber.from(args.mingastostore),
      LayerZeroEndpoints[hre.network.name],
    ] as const;
  } else {
    contractName = ContractDetails.ONFT721Lite.name;
    deployParams = [
      args.name,
      args.symbol,
      hre.ethers.BigNumber.from(args.mingastostore),
      LayerZeroEndpoints[hre.network.name],
    ] as const;
  }

  console.log(
    `Going to deploy ${contractName} with params`,
    JSON.stringify(args, null, 2),
  );

  console.log(
    `Constructor params: `,
    JSON.stringify(
      deployParams?.map((param) => {
        if (hre.ethers.BigNumber.isBigNumber(param)) {
          return param.toString();
        }
        return param;
      }),
    ),
  );

  if (!await confirm({ message: 'Continue to deploy?' })) return;

  const contract = await hre.ethers.getContractFactory(contractName);
  const erc721MOnft = await contract.deploy(...deployParams);

  await erc721MOnft.deployed();

  console.log(`${contractName} deployed to:`, erc721MOnft.address);
};
