import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ISetCrossmintAddress {
  crossmintaddress: string;
  contract: string;
}

export const setCrossmintAddress = async (
  args: ISetCrossmintAddress,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setCrossmintAddress(args.crossmintaddress);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();
  console.log('Set crossmint address:', tx.hash);

  const crossmintAddress = await contract.getCrossmintAddress();
  console.log(`New crossmint address: ${crossmintAddress}`);
};
