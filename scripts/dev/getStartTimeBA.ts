import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from '../common/constants';

export interface IGetStartTimeBAParams {
  contract: string;
}

export const getStartTimeBA = async (
  args: IGetStartTimeBAParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  const tx = await contract.getStartTimeUnixSecods();
  console.log(`Result: ${tx}`);
};
