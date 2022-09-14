import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ISetPausedParams {
  paused?: boolean;
  contract: string;
}

export const setPaused = async (
  args: ISetPausedParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setPaused(Boolean(args.paused));
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set paused:', tx.hash);

  const paused = await contract.isPaused();
  console.log(`New paused state: ${paused}`);
};
