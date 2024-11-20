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

interface IDeployRandomGameParams {
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  globalwalletlimit: string;
  cosigner?: string;
  timestampexpiryseconds?: number;
  useoperatorfilterer?: boolean;
  openedition?: boolean;
  mintcurrency?: string;
  fundreceiver?: string;
  proxycontract: string;
  gaspricegwei?: number;
  gaslimit?: number;
}

export const deployRandomGame = async (
  args: IDeployRandomGameParams,
  hre: HardhatRuntimeEnvironment,
) => {
  console.log("123");
  // Compile again in case we have a coverage build (binary too large to deploy)
  const contractName = 'RandomGamesMinting';

  let maxsupply = hre.ethers.BigNumber.from(args.maxsupply);

  if (args.openedition) {
    maxsupply = hre.ethers.BigNumber.from('999999999');
  }

  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = hre.ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = hre.ethers.BigNumber.from(args.gaslimit);
  }

  const [signer] = await hre.ethers.getSigners();
  const contractFactory = await hre.ethers.getContractFactory(contractName, signer);

  const params = [
    args.name,
    args.symbol,
    args.tokenurisuffix,
    maxsupply,
    hre.ethers.BigNumber.from(args.globalwalletlimit),
    args.cosigner ?? hre.ethers.constants.AddressZero,
    args.timestampexpiryseconds ?? 300,
    args.mintcurrency ?? hre.ethers.constants.AddressZero,
    args.fundreceiver ?? signer.address,
    args.proxycontract,
  ] as any[];

  console.log(
    `Going to deploy ${contractName} with params`,
    JSON.stringify(args, null, 2),
  );

  if (
    !(await estimateGas(
      hre,
      contractFactory.getDeployTransaction(
        args.name,
        args.symbol,
        args.tokenurisuffix,
        maxsupply,
        hre.ethers.BigNumber.from(args.globalwalletlimit),
        args.cosigner ?? hre.ethers.constants.AddressZero,
        args.timestampexpiryseconds ?? 300,
        args.mintcurrency ?? hre.ethers.constants.AddressZero,
        args.fundreceiver ?? signer.address,
        args.proxycontract,
      ),
      overrides,
    ))
  )
    return;

  if (!(await confirm({ message: 'Continue to deploy?' }))) return;

  const contract = await contractFactory.deploy(
    args.name,
    args.symbol,
    args.tokenurisuffix,
    maxsupply,
    hre.ethers.BigNumber.from(args.globalwalletlimit),
    args.cosigner ?? hre.ethers.constants.AddressZero,
    args.timestampexpiryseconds ?? 300,
    args.mintcurrency ?? hre.ethers.constants.AddressZero,
    args.fundreceiver ?? signer.address,
    args.proxycontract,
    overrides);
  console.log('Deploying contract... ');
  console.log('tx:', contract.deployTransaction.hash);

  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
  console.log('run the following command to verify the contract:');
  const paramsStr = params
    .map((param) => {
      if (hre.ethers.BigNumber.isBigNumber(param)) {
        return `"${param.toString()}"`;
      }
      return `"${param}"`;
    })
    .join(' ');

  console.log(
    `npx hardhat verify --network ${hre.network.name} ${contract.address} ${paramsStr}`,
  );

};
