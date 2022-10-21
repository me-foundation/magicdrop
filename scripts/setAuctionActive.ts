import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ISetAuctionActiveParams {
  auctionActive: boolean;
  contract: string;
  contractName: string;
}

export const setAuctionActive = async (
  args: ISetAuctionActiveParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // Get the contract name to be initialized; defaults to BucketAuction
  const contractName = args.contractName ?? 'BucketAuction';
  const { ethers } = hre;
  const contractFactory = await ethers.getContractFactory(contractName);
  const contract = contractFactory.attach(args.contract);

  // Set the auction active
  console.log(`New auction state to be set: ${args.auctionActive}`);
  const tx = await contract.setAuctionActive(args.auctionActive);
  console.log(`Submitted tx ${tx.hash}`);
  await tx.wait();
  console.log('Set active stage:', tx.hash);
};
