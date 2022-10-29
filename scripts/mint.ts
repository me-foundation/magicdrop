import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';

export interface IMintParams {
  contract: string;
  quantity?: string;
  minttime: number;
}

export const mint = async (
  args: IMintParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);
  const timestamp = Math.floor(new Date(args.minttime).getTime() / 1000);
  const stageIndex = await contract.getActiveStageFromTimestamp(timestamp);
  const [stageInfo] = await contract.getStageInfo(stageIndex);
  const qty = ethers.BigNumber.from(args.quantity ?? 1);
  const tx = await contract.mint(qty, [], timestamp, '0x', {
    value: stageInfo.price.mul(qty),
  });
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log(`Minted ${qty.toNumber()} tokens`);
};
