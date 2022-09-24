import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface IMintParams {
  contract: string;
  quantity?: string;
}

export const mint = async (
  args: IMintParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const activeStage = await contract.getActiveStage();
  const [stageInfo] = await contract.getStageInfo(activeStage);
  const qty = ethers.BigNumber.from(args.quantity ?? 1);
  const tx = await contract.mint(qty, [ethers.utils.hexZeroPad('0x', 32)], {
    value: stageInfo.price.mul(qty),
  });
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log(`Minted ${qty.toNumber()} tokens`);
};
