import { HardhatRuntimeEnvironment } from 'hardhat/types';

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
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach(args.contract);
  const qty = ethers.BigNumber.from(args.qty ?? 1);
  const tx = await contract.ownerMint(
    qty,
    args.to ?? (await contract.signer.getAddress()),
  );
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log(`Minted ${qty.toNumber()} tokens`);
};
