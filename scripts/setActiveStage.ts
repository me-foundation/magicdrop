import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { SaleTypes, StageTypes } from './common/constants';

export interface ISetActiveStageParams {
  stage: number;
  contract: string;
}

export const setActiveStage = async (
  args: ISetActiveStageParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(SaleTypes.ERC721M.strVal);
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setActiveStage(args.stage);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set active stage:', tx.hash);

  const [stage] = await contract.getStageInfo(args.stage);
  console.log(`New active stage: ${stage}`);
};
