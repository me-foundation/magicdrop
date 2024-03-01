import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';
import { estimateGas } from './utils/helper';

export interface IThawTrading {
  contract: string;
}

export const thawTrading = async (
  args: IThawTrading,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const factory = await ethers.getContractFactory(ContractDetails.ERC721CM.name);
  const contract = factory.attach(args.contract);

  const tx = await contract.populateTransaction.setToDefaultSecurityPolicy();
  await estimateGas(hre, tx);
  console.log(`Going to thaw contract: ${args.contract}`);
  if (!await confirm({ message: 'Continue?' })) return;

  const submittedTx = await contract.setToDefaultSecurityPolicy();

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log(`Contract ${args.contract} thawed`);
};
