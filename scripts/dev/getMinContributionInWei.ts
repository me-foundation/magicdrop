import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from '../common/constants';

export interface IGetMinContributionInWeiParams {
  contract: string;
}

export const getMinContributionInWei = async (
  args: IGetMinContributionInWeiParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  const tx = await contract.getMinimumContributionInWei();
  console.log(`Result: ${tx}`);
};
