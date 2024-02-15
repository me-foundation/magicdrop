import { confirm } from '@inquirer/prompts';
import { Deferrable } from 'ethers/lib/utils';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TransactionRequest } from "@ethersproject/abstract-provider";
import * as child from 'child_process';

export const checkCodeVersion = async () => {
  const localLatestCommit = child.execSync('git rev-parse HEAD').toString().trim();
  const remoteLatestCommit = child.execSync("git ls-remote https://github.com/magicoss/erc721m.git HEAD | awk '{ print $1}'").toString().trim();
  console.log('local latest commit:\t', localLatestCommit);
  console.log('remote latest commit:\t', remoteLatestCommit);

  if (localLatestCommit !== remoteLatestCommit) {
    console.log("🟡 Warning: you are NOT using the latest version of the code. Please run `git pull` on main branch to update the code.");
    if (!(await confirm({ message: 'Proceed anyway?', default: false }))) {
      process.exit(0);
    };
  }
}

export const estimateGas = async (hre: HardhatRuntimeEnvironment, tx: Deferrable<TransactionRequest>) => {
  const estimatedGasUnit = await hre.ethers.provider.estimateGas(tx);
  const estimatedGasPrice = await hre.ethers.provider.getGasPrice();
  const estimatedGas = estimatedGasUnit.mul(estimatedGasPrice);
  console.log('Estimated gas unit: ', estimatedGasUnit.toString());
  console.log('Estimated gas price (GWei): ', estimatedGasPrice.div(1000000000).toString());
  console.log(`Estimated gas (${getTokenName(hre)}): `, hre.ethers.utils.formatEther(estimatedGas));
  return estimatedGas;
}

const getTokenName = (hre: HardhatRuntimeEnvironment) => {
  switch(hre.network.name) {
    case 'mainnet':
    case 'sepolia':
    case 'goerli':
      return 'ETH';
    case 'polygon':
    case 'mumbai':
      return 'MATIC';
    default:
      return 'ETH';
  }
}

