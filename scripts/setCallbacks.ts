// 0x73b10f25e65C37Be2Aeb9e4e8A8e53464C56dcE9

import { HardhatRuntimeEnvironment } from 'hardhat/types';
import fs from 'fs';

export interface ISetCallbacksParams {
  contract: string;
  callbackconfigsfile: string;
}

type CallbackConfig = {
  callbackContract: string;
  callbackFunction: string;
};

export const setCallbacks = async (
  args: ISetCallbacksParams,
  hre: HardhatRuntimeEnvironment,
) => {
  const { ethers } = hre;
  const ERC721MCallback = await ethers.getContractFactory('ERC721MCallback');
  const contract = ERC721MCallback.attach(args.contract);
  const callbackConfigs: CallbackConfig[] = JSON.parse(
    fs.readFileSync(args.callbackconfigsfile, 'utf-8'),
  );
  const tx = await contract.setCallbackInfos(callbackConfigs);
  console.log(`Submitted tx ${tx.hash}`);

  await tx.wait();

  console.log(
    `Sets callback infos: ${JSON.stringify(callbackConfigs, null, 2)}`,
  );
};
