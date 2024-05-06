import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { ContractDetails } from './common/constants';
import { Overrides } from 'ethers';
import { estimateGas } from './utils/helper';

interface ISetBaseURIParams {
  uri: string;
  contract: string;
  gaspricegwei?: number;
  gaslimit?: number;
}

export const setBaseURI = async (
  args: ISetBaseURIParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const overrides: Overrides = {};
  if (args.gaspricegwei) {
    overrides.gasPrice = ethers.BigNumber.from(args.gaspricegwei * 1e9);
  }
  if (args.gaslimit) {
    overrides.gasLimit = ethers.BigNumber.from(args.gaslimit);
  }
  const ERC721M = await ethers.getContractFactory(ContractDetails.ERC721M.name);
  const contract = ERC721M.attach(args.contract);
  const tx = await contract.populateTransaction.setBaseURI(args.uri);
  if (!(await estimateGas(hre, tx, overrides))) return;
  const submittedTx = await contract.setBaseURI(args.uri, overrides);

  console.log(`Submitted tx ${submittedTx.hash}`);

  await submittedTx.wait();

  console.log('Set baseURI:', submittedTx.hash);
};
