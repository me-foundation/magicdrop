import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ISetBaseURIParams {
  uri: string;
  contract: string;
}

export const setBaseURI = async (
  args: ISetBaseURIParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setBaseURI(args.uri);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set baseURI:', tx.hash);
};
