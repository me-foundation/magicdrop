import { encodeFunctionData, Hex } from 'viem';
import { actionPresets } from './common';
import { ERC712M_ABIS } from '../../abis';
import { printTransactionHash, showError, showText } from '../display';
import { TOKEN_STANDARD } from '../constants';

export const setMintableAction = async (
  collection: string,
  params: {
    mintable: boolean;
  },
) => {
  try {
    const { cm, config, store } = await actionPresets(collection);
    if (config.tokenStandard !== TOKEN_STANDARD.ERC721)
      throw new Error(
        `this action is only supported for ${TOKEN_STANDARD.ERC721} collections`,
      );

    const data = encodeFunctionData({
      abi: [ERC712M_ABIS.setMintable],
      functionName: ERC712M_ABIS.setMintable.name,
      args: [params.mintable],
    });

    showText(
      `Setting contract to ${params.mintable ? '' : 'NOT'} mintable... this will take a moment`,
    );
    const txHash = await cm.sendTransaction({
      to: config.deployment!.contract_address as Hex,
      data,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);
    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    store.data!.mintable = params.mintable;
    store.write();

    printTransactionHash(receipt.transactionHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Error setting mintable: ${error.message}` });
  }
};
