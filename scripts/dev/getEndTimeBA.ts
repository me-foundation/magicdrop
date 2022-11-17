import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from '../common/constants';

export interface IGetEndTimeBAParams {
  contract: string;
}

export const getEndTimeBA = async (
  args: IGetEndTimeBAParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  const tx = await contract.getEndTimeUnixSecods();
  console.log(`Result: ${tx}`);
};
