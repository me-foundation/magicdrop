import { confirm } from '@inquirer/prompts';
import { ChainIds, ContractDetails } from './common/constants';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

export interface ISetTrustedRemoteParams {
    sourceaddress: string;
    targetnetwork: string;
    targetaddress: string;
}

export const setTrustedRemote = async (
    args: ISetTrustedRemoteParams,
    hre: HardhatRuntimeEnvironment,
  ) => {
    const supportedNetworks = Object.keys(ChainIds);
    if (!supportedNetworks.includes(args.targetnetwork)) {
        throw new Error(`Invalid network. Supported networks are: ${supportedNetworks.join(', ')}`);
    }
    const remoteChainId = ChainIds[args.targetnetwork];

    const remoteAndLocal = hre.ethers.utils.solidityPack(
        ['address','address'],
        [args.targetaddress, args.sourceaddress]
    );

    const { ethers } = hre;
    const ERC721MOnft = await ethers.getContractFactory(
      ContractDetails.ERC721MOnft.name,
    );
    const contract = ERC721MOnft.attach(args.sourceaddress);

    console.log(`Setting TrustedRemote on ${hre.network.name}/${args.sourceaddress} to target ${args.targetnetwork}/${args.targetaddress}`)
    if (!await confirm({ message: 'Continue?' })) return;

    try {
        const tx = await contract.setTrustedRemote(remoteChainId, remoteAndLocal);
        console.log(`Submitted tx ${tx.hash}`);
        await tx.wait();
        console.log(`✅ Set TrustedRemote on ${hre.network.name}/${args.sourceaddress} to target ${args.targetnetwork}/${args.targetaddress}`)
    } catch (error) {
        console.log(error);
    }
}
