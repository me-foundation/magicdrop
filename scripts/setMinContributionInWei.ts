import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';

export interface ISetMinContributionInWeiParams {
  contract: string;
  mincontributioninwei: number;
}

export const setMinContributionInWei = async (
  args: ISetMinContributionInWeiParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  // Set the parameters for the contract function
  const params = [ethers.BigNumber.from(args.mincontributioninwei)] as const;

  const tx = await contract.setMinimumContribution(...params);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set baseURI:', tx.hash);
};
