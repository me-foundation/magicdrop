// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { getSaleEnumValueByName } from './common/utils';

export interface IDeployParams {
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  globalwalletlimit: string;
  cosigner?: string;
  contractname?: string;
  mincontributioninwei?: number; // Required only for the BucketAuction
}

export const deploy = async (
  args: IDeployParams,
  hre: HardhatRuntimeEnvironment,
) => {
  // Get the contract name to be initialized; defaults to ERC721M
  const contractName = args.contractname ?? 'ERC721M';
  console.log(
    `Going to deploy ${contractName} with params`,
    JSON.stringify(args, null, 2),
  );
  const contractFactory = await hre.ethers.getContractFactory(contractName);
  // Set the base parameters for ERC721M
  const params = [
    args.name,
    args.symbol,
    args.tokenurisuffix,
    hre.ethers.BigNumber.from(args.maxsupply),
    hre.ethers.BigNumber.from(args.globalwalletlimit),
    args.cosigner ?? hre.ethers.constants.AddressZero,
  ];
  // Set the additional parameters e.g. for the BucketAuction
  if (getSaleEnumValueByName(contractName) == 1) {
    params.push(hre.ethers.BigNumber.from(args.mincontributioninwei ?? 0.01));
  }

  const contract = await contractFactory.deploy(...params);

  await contract.deployed();

  console.log(`${contractName} deployed to:`, contract.address);
};
