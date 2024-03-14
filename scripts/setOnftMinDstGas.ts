import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ChainIds, ContractDetails } from './common/constants';

export interface ISetOnftMinDstGas {
  contract: string;
  targetnetwork: string;
  packettype: string;
  mingas: string;
}

export const setOnftMinDstGas = async (
  args: ISetOnftMinDstGas,
  hre: HardhatRuntimeEnvironment,
) => {
  const supportedNetworks = Object.keys(ChainIds);
  if (!supportedNetworks.includes(args.targetnetwork)) {
    throw new Error(
      `Invalid network. Supported networks are: ${supportedNetworks.join(', ')}`,
    );
  }
  const { ethers } = hre;
  const ERC721MOnft = await ethers.getContractFactory(
    ContractDetails.ERC721MOnft.name,
  );
  const contract = ERC721MOnft.attach(args.contract);
  const dstChainId = ChainIds[args.targetnetwork];

  console.log(
    `Setting min destination gas for ${hre.network.name}/${args.contract} to packetType: ${args.packettype} and minGas: ${args.mingas}`,
  );
  if (!(await confirm({ message: 'Continue?' }))) return;

  try {
    const tx = await contract.setMinDstGas(
      dstChainId,
      args.packettype,
      args.mingas,
    );
    console.log(`Submitted tx ${tx.hash}`);
    await tx.wait();
    console.log(`✅ Sent.`);
  } catch (error) {
    console.log(error);
  }
};
