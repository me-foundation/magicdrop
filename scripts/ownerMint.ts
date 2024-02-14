import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';
import { estimateGas } from './utils/helper';

export interface IOwnerMintParams {
  contract: string;
  to?: string;
  qty?: string;
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

  const tx = await contract.populateTransaction.ownerMint(qty, to);
  estimateGas(hre, tx);
  console.log(`Going to mint ${qty.toNumber()} token(s) to ${to}`);
  if (!await confirm({ message: 'Continue?' })) return;

  const submittedTx = await contract.ownerMint(qty, to);

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log(`Minted ${qty.toNumber()} token(s) to ${to}`);
};
