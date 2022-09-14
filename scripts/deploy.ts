// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface IDeployParams {
  name: string;
  symbol: string;
  maxsupply: string;
  globalwalletlimit: string;
}

export const deploy = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const ERC721M = await hre.ethers.getContractFactory('ERC721M');
  const erc721M = await ERC721M.deploy(
    args.name,
    args.symbol,
    hre.ethers.BigNumber.from(args.maxsupply),
    hre.ethers.BigNumber.from(args.globalwalletlimit),
  );

  await erc721M.deployed();

  console.log('ERC721M deployed to:', erc721M.address);
};
