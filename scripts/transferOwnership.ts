import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ITransferOwnershipParams {
  owner: string;
  contract: string;
}

export const transferOwnership = async (
  args: ITransferOwnershipParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.transferOwnership(args.owner);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('New owner:', await contract.owner());
};
