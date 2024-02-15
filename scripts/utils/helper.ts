import { Deferrable } from 'ethers/lib/utils';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TransactionRequest } from "@ethersproject/abstract-provider";

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

