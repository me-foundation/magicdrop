import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
  ContractDetails,
  ERC721CMRoyaltiesCloneFactoryContract,
} from '../common/constants';
import { estimateGas } from '../utils/helper';
import { Overrides } from 'ethers';

export interface IDeployCloneParams {
  name: string;
  symbol: string;
  tokenurisuffix: string;
  maxsupply: string;
  globalwalletlimit: string;
  timestampexpiryseconds: number;
  mintcurrency: string;
  fundreceiver: string;
  royaltyreceiver: string;
  royaltyfeenumerator: number;
  openedition: boolean;
  gaspricegwei?: number;
  gaslimit?: number;
}

export const deployClone = async (
  args: IDeployCloneParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const factory = await ethers.getContractFactory(
    ContractDetails.ERC721CMRoyaltiesCloneFactory.name,
  );
  const factoryContract = factory.attach(ERC721CMRoyaltiesCloneFactoryContract);

  if (args.openedition) {
    args.maxsupply = '999999999';
  }

  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = ethers.BigNumber.from(args.gaslimit);
  }

  const tx = await factoryContract.populateTransaction.create(
    args.name,
    args.symbol,
    args.tokenurisuffix,
    args.maxsupply,
    args.globalwalletlimit,
    args.timestampexpiryseconds,
    args.mintcurrency,
    args.fundreceiver,
    args.royaltyreceiver,
    args.royaltyfeenumerator,
  );

  if (!(await estimateGas(hre, tx, overrides))) return;
  console.log(`Going to create a clone.`);
  if (!(await confirm({ message: 'Continue?' }))) return;

  const signedTx = await factoryContract.create(
    args.name,
    args.symbol,
    args.tokenurisuffix,
    args.maxsupply,
    args.globalwalletlimit,
    args.timestampexpiryseconds,
    args.mintcurrency,
    args.fundreceiver,
    args.royaltyreceiver,
    args.royaltyfeenumerator,
    overrides,
  );

  console.log(`Submitted tx ${signedTx.hash}`);
  const receipt = await signedTx.wait();
  console.log(`Clone deployed at ${receipt.logs[0].address}`);
};
