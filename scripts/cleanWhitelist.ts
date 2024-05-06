import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { cleanWhitelist as cleanWL, cleanVariableWalletLimit } from './utils/helper';

export interface ICleanWhitelistParams {
  whitelistpath: string;
  variablewalletlimitpath: string;
}

export const cleanWhitelist = async (
  args: ICleanWhitelistParams,
  hre: HardhatRuntimeEnvironment,
) => {
  if (args.variablewalletlimitpath) {
    cleanVariableWalletLimit(args.variablewalletlimitpath, true);
  }

  if (args.whitelistpath) {
    cleanWL(args.whitelistpath, true);
  }
};
