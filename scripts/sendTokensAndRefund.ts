import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';

export interface ISendTokensRefundParams {
  contract: string;
  to: string;
}

export const sendTokensAndRefund = async (
  args: ISendTokensRefundParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  // Set the parameters for the contract function
  const params = [args.to] as const;

  const tx = await contract.sendTokensAndRefund(...params);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();
};
