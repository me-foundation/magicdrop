import { confirm } from '@inquirer/prompts';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
  ContractDetails,
  ERC721CV2_EMPTY_LIST,
  ERC721CV2_FREEZE_LEVEL,
  ERC721CV2_VALIDATOR,
} from '../common/constants';
import { estimateGas } from '../utils/helper';

export interface IFreezeTrading {
  contract: string;
  validator?: string;
  level?: number;
  whitelistid?: number;
  permittedreceiverid?: number;
}

export const freezeTrading = async (
  args: IFreezeTrading,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const factory = await ethers.getContractFactory(
    ContractDetails.ERC721CM.name,
  );
  const contract = factory.attach(args.contract);

  const validator = args.validator ?? ERC721CV2_VALIDATOR;
  const level = args.level ?? ERC721CV2_FREEZE_LEVEL;
  const whitelistid = args.whitelistid ?? ERC721CV2_EMPTY_LIST;
  const permittedreceiverid = args.permittedreceiverid ?? ERC721CV2_EMPTY_LIST;

  const tx =
    await contract.populateTransaction.setToCustomValidatorAndSecurityPolicy(
      validator,
      level,
      whitelistid,
      permittedreceiverid,
    );
  await estimateGas(hre, tx);
  console.log(`Going to freeze contract: ${args.contract}`);
  if (!(await confirm({ message: 'Continue?' }))) return;

  const submittedTx = await contract.setToCustomValidatorAndSecurityPolicy(
    validator,
    level,
    whitelistid,
    permittedreceiverid,
  );

  console.log(`Submitted tx ${submittedTx.hash}`);
  await submittedTx.wait();
  console.log(`Contract ${args.contract} freezed`);
};
