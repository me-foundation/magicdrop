import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ChainIds, ContractDetails } from './common/constants';

export interface ISendOnftParams {
  contract: string;
  tokenowner: string;
  targetnetwork: string;
  tokenid: string;
  newowner?: string;
  refundaddress?: string;
  zeropaymentaddress?: string;
}

export const sendOnft = async (
    args: ISendOnftParams,
    hre: HardhatRuntimeEnvironment,
  ) => {
    const supportedNetworks = Object.keys(ChainIds);
    if (!supportedNetworks.includes(args.targetnetwork)) {
        throw new Error(`Invalid network. Supported networks are: ${supportedNetworks.join(', ')}`);
    }

    console.log(1);

    const { ethers } = hre;
    const ERC721MOnft = await ethers.getContractFactory(
      ContractDetails.ERC721MOnft.name,
    );
    const contract = ERC721MOnft.attach(args.contract);

    const targetChainId = ChainIds[args.targetnetwork];
    const newOwner = args.newowner ?? args.tokenowner;
    const refundAddress = args.refundaddress ?? args.tokenowner;
    const zeroPaymentAddress = args.refundaddress ?? ethers.constants.AddressZero;

    // quote fee with default adapterParams
    const adapterParams = ethers.utils.solidityPack(["uint16", "uint256"], [1, 200000]) // default adapterParams example
    console.log(adapterParams);

    console.log(2);

    const fees = await contract.estimateSendFee(targetChainId, newOwner, args.tokenid, /* useZro= */false, adapterParams);
    console.log(3);

    const nativeFee = fees[0];
    console.log(`native fees (wei): ${nativeFee}`)

    console.log();

    try {
        const tx = await contract.sendFrom(args.tokenowner, targetChainId, newOwner, args.tokenid, refundAddress, zeroPaymentAddress, adapterParams, { value: nativeFee.mul(5).div(4), gasLimit: 2_500_000 });
        console.log(`Submitted tx ${tx.hash}`);
        await tx.wait();
        console.log(`✅ Sent.`)
    } catch (error) {
        console.log(error);
    }
}

