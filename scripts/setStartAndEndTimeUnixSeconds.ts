import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';

export interface ISetStartAndEndTimeUnixSecondsParams {
  contract: string;
  starttime: string;
  endtime: string;
}

export const setStartAndEndTimeUnixSeconds = async (
  args: ISetStartAndEndTimeUnixSecondsParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  // Set the parameters for the contract function
  const params = [
    Math.floor(new Date(args.starttime).getTime() / 1000),
    Math.floor(new Date(args.endtime).getTime() / 1000),
  ] as const;

  const tx = await contract.setStartAndEndTimeUnixSeconds(...params);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('Set baseURI:', tx.hash);
};
