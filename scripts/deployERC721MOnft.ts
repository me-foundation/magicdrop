// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails, LayerZeroEndpoints } from './common/constants';

export interface IDeployParams {
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  cosigner?: string;
  timestampexpiryseconds?: number;
  increasesupply?: boolean;
  minGasToStore: string;
}

export const deployERC721MOnft = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {

  const contractName = ContractDetails.ERC721MOnft.name;

  console.log(
    `Going to deploy ${contractName} with params`,
    JSON.stringify(args, null, 2),
  );

  const params = [
    args.name,
    args.symbol,
    args.tokenurisuffix,
    hre.ethers.BigNumber.from(args.maxsupply),
    args.cosigner ?? hre.ethers.constants.AddressZero,
    args.timestampexpiryseconds ?? 300,
    hre.ethers.BigNumber.from(args.minGasToStore),
    LayerZeroEndpoints[hre.network.name],
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

  if (!await confirm({ message: 'Continue to deploy?' })) return;

  const contract = await hre.ethers.getContractFactory(contractName);
  const erc721MOnft = await contract.deploy(...params);

  await erc721MOnft.deployed();

  console.log(`${contractName} deployed to:`, erc721MOnft.address);
};
