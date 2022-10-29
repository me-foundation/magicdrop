import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ISetBaseURIParams {
  supply: string;
  contract: string;
}

export const setMaxMintableSupply = async (
  args: ISetBaseURIParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory('ERC721MCallback');
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setMaxMintableSupply(parseInt(args.supply, 10), {
    nonce: 12,
    gasPrice: ethers.utils.parseUnits('30', 'gwei'),
  });
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set max mintable supply:', tx.hash);
};
