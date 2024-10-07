import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from '../common/constants';
import fs from 'fs';

export interface ISendRefundBatchParams {
  contract: string;
  addresses: string;
}

export const sendRefundBatch = async (
  args: ISendRefundBatchParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const addresses = JSON.parse(
    fs.readFileSync(args.addresses, 'utf-8'),
  ) as string[];

  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  // Set the parameters for the contract function
  const params = [addresses] as const;
  console.log(`Params:`, JSON.stringify(params));

  const tx = await contract.sendRefundBatch(...params);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();
};
