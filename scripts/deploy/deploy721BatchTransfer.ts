import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { estimateGas } from '../utils/helper';

export const deploy721BatchTransfer = async (
  args: {},
  hre: HardhatRuntimeEnvironment,
) => {
  const [signer] = await hre.ethers.getSigners();
  const factory = await hre.ethers.getContractFactory(
    'ERC721BatchTransfer',
    signer,
  );

  await estimateGas(hre, factory.getDeployTransaction());

  if (!(await confirm({ message: 'Continue to deploy?' }))) return;

  const contract = await factory.deploy();
  await contract.deployed();
  console.log('ERC721BatchTransfer deployed to:', contract.address);
};
