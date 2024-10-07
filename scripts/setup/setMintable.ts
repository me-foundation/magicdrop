import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from '../common/constants';

export interface ISetMintableParams {
  mintable: boolean;
  contract: string;
}

export const setMintable = async (
  args: ISetMintableParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setMintable(Boolean(args.mintable));
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set mintable:', tx.hash);

  const mintable = await contract.getMintable();
  console.log(`New mintable state: ${mintable}`);
};
