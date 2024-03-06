import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';
import { estimateGas } from './utils/helper';
import { Overrides } from 'ethers';

export interface IOwnerMintParams {
  contract: string;
  to?: string;
  qty?: string;
  gaspricegwei?: number;
  gaslimit?: number;
}

export const ownerMint = async (
  args: IOwnerMintParams,
  hre: HardhatRuntimeEnvironment,
) => {
  console.log(`Minting ${args.qty ?? 1} tokens to ${args.to}...`);
  const { ethers } = hre;
  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);
  const qty = ethers.BigNumber.from(args.qty ?? 1);
  const to = args.to ?? (await contract.signer.getAddress());
  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = ethers.BigNumber.from(args.gaslimit);
  }

  const tx = await contract.populateTransaction.ownerMint(qty, to);
  if (!(await estimateGas(hre, tx, overrides))) return;
  console.log(`Going to mint ${qty.toNumber()} token(s) to ${to}`);
  if (!await confirm({ message: 'Continue?' })) return;

  const submittedTx = await contract.ownerMint(qty, to, overrides);

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log(`Minted ${qty.toNumber()} token(s) to ${to}`);
};
