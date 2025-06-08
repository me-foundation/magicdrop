import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from '../common/constants';

export interface ISetPriceParams {
  contract: string;
  priceinwei: number;
}

export const setPrice = async (
  args: ISetPriceParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const overrides: any = { gasLimit: 500_000 };
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(
    ContractDetails.BucketAuction.name,
  );
  const contract = ERC721M.attach(args.contract);

  const tx = await contract.setPrice(
    ethers.BigNumber.from(args.priceinwei),
    overrides,
  );
  console.log(`Result: ${tx.hash}`);

  await tx.wait();
};
