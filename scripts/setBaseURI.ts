import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';

export interface ISetBaseURIParams {
  uri: string;
  contract: string;
  gaspricegwei?: number;
}

export const setBaseURI = async (
  args: ISetBaseURIParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  let overrides: any = {gasLimit: 500_000};

  if (args.gaspricegwei) {
    overrides.gasPrice = args.gaspricegwei * 1e9;
  }
  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setBaseURI(args.uri, overrides);

  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set baseURI:', tx.hash);
};
