// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.

import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';
import { checkCodeVersion, estimateGas } from './utils/helper';
import { Overrides } from 'ethers';

interface IDeployCloneFactoryParams {
  gaspricegwei?: number;
  gaslimit?: number;
}

export const deployCloneFactory = async (
  args: IDeployCloneFactoryParams,
  hre: HardhatRuntimeEnvironment,
) => {
  if (!(await checkCodeVersion())) {
    return;
  }

  // Compile again in case we have a coverage build (binary too large to deploy)
  await hre.run('compile');
  const contractName: string = ContractDetails.ERC721CMRoyaltiesCloneFactory.name;
  const contractFactory = await hre.ethers.getContractFactory(contractName);

  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = hre.ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = hre.ethers.BigNumber.from(args.gaslimit);
  }

  console.log(`Going to deploy ${contractName}.`);

  if (
    !(await estimateGas(
      hre,
      contractFactory.getDeployTransaction(),
      overrides,
    ))
  ) {
    return;
  }

  if (!(await confirm({ message: 'Continue to deploy?' }))) return;

  const contract = await contractFactory.deploy(overrides);
  console.log('Deploying contract... ');
  console.log('tx:', contract.deployTransaction.hash);

  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
  console.log(
    `npx hardhat verify --network ${hre.network.name} ${contract.address}`,
  );
};
