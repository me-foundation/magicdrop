import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';

export interface ISetTimestampExpirySeconds {
  timestampexpiryseconds: string;
  contract: string;
}

export const setTimestampExpirySeconds = async (
  args: ISetTimestampExpirySeconds,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.setTimestampExpirySeconds(
    parseInt(args.timestampexpiryseconds, 10),
  );
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log('New expiry:', await contract.getTimestampExpirySeconds());
  console.log(
    'Make sure to update stages to have sufficient gap to account for the new timestamp expiry!',
  );
};
