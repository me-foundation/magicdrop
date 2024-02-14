import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const getContractCodehash = async (
  args: { contract: string },
  hre: HardhatRuntimeEnvironment
) => {
  const [signer] = await hre.ethers.getSigners();
  const provider = signer.provider;
  let code = await provider!.getCode(args.contract);
  const codehash = hre.ethers.utils.keccak256(code);
  console.log(codehash);
}
