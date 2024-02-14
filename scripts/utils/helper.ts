import { Deferrable } from 'ethers/lib/utils';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TransactionRequest } from "@ethersproject/abstract-provider";

export const estimateGas = async (hre: HardhatRuntimeEnvironment, tx: Deferrable<TransactionRequest>) => {
  const estimatedGasUnit = await hre.ethers.provider.estimateGas(tx);
  const estimatedGasPrice = await hre.ethers.provider.getGasPrice();
  const estimatedGas = estimatedGasUnit.mul(estimatedGasPrice);
  console.log('Estimated gas unit: ', estimatedGasUnit.toString());
  console.log('Estimated gas price (WEI): ', estimatedGasPrice.toString());
  console.log('Estimated gas (ETH): ', hre.ethers.utils.formatEther(estimatedGas));
  return estimatedGas;
}

