import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from '../common/constants';
import { estimateGas } from '../utils/helper';
import { Overrides } from 'ethers';

export interface IOwnerMint1155Params {
  contract: string;
  to?: string;
  id: string;
  qty: string;
  gaspricegwei?: number;
  gaslimit?: number;
}

export const ownerMint1155 = async (
  args: IOwnerMint1155Params,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const factory = await ethers.getContractFactory(
    ContractDetails.ERC1155M.name,
  );
  const contract = factory.attach(args.contract);
  const tokenId = ethers.BigNumber.from(args.id);
  const qty = ethers.BigNumber.from(args.qty);
  const to = args.to ?? (await contract.signer.getAddress());
  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = ethers.BigNumber.from(args.gaslimit);
  }

  const tx = await contract.populateTransaction.ownerMint(to, tokenId, qty);
  if (!(await estimateGas(hre, tx, overrides))) return;
  console.log(
    `Going to mint ${qty.toNumber()} token(s) with tokenId = ${tokenId.toNumber()} to ${to}`,
  );
  if (!(await confirm({ message: 'Continue?' }))) return;

  const submittedTx = await contract.ownerMint(to, tokenId, qty, overrides);

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log(
    `Minted ${qty.toNumber()} token(s) with tokenId = ${tokenId.toNumber()} to ${to}`,
  );
};
