import { HardhatRuntimeEnvironment } from 'hardhat/types';

interface ISetBaseURIParams {
  supply: string;
  contract: string;
}

export const setMaxMintableSupply = async (
  args: ISetBaseURIParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setMaxMintableSupply(parseInt(args.supply, 10));
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set max mintable supply:', tx.hash);
};
