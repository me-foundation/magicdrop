import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ISetApprovalsOnMintParams {
  contract: string;
  approvals: string;
}

export const setOnMintApprovals = async (
  args: ISetApprovalsOnMintParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721MCallback = await ethers.getContractFactory('ERC721MCallback');
  const contract = ERC721MCallback.attach(args.contract);
  const approvals = args.approvals.split(',').map((a) => a.trim());

  const tx = await contract.setOnMintApprovals(approvals);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log(`Set approvals: ${JSON.stringify(approvals, null, 2)}`);
};
