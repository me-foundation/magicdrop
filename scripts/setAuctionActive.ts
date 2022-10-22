import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { SaleTypes } from './common/constants';

export interface ISetAuctionActiveParams {
  auctionactive: boolean;
  contract: string;
  contractname: string;
}

export const setAuctionActive = async (
  args: ISetAuctionActiveParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // Get the contract name to be initialized; defaults to BucketAuction
  const contractName = args.contractname ?? SaleTypes.BucketAuction.strVal;
  const { ethers } = hre;
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = contractFactory.attach(args.contract);

  // Set the auction active
  console.log(
    `New auction state to be set for ${contractName}: ${args.auctionactive}`,
  );
  const tx = await contract.setAuctionActive(args.auctionactive);
  console.log(`Submitted tx ${tx.hash}`);
  await tx.wait();
  console.log('Set active stage:', tx.hash);
};
