import { encodeFunctionData, Hex, isAddress } from 'viem';
import { actionPresets } from './common';
import { SET_COSIGNER_ABI } from '../../abis';
import { printTransactionHash, showError, showText } from '../display';
import { TOKEN_STANDARD } from '../constants';

export const setCosignerAction = async (
  collection: string,
  params: {
    cosigner: Hex;
  },
) => {
  try {
    const { cm, config, store } = await actionPresets(collection);
    if (config.tokenStandard !== TOKEN_STANDARD.ERC721)
      throw new Error(
        `this action is only supported for ${TOKEN_STANDARD.ERC721}  collections`,
      );

    if (!isAddress(params.cosigner))
      throw new Error('cosigner must be a valid address');

    const data = encodeFunctionData({
      abi: [SET_COSIGNER_ABI],
      functionName: SET_COSIGNER_ABI.name,
      args: [params.cosigner],
    });

    showText(
      `Setting cosigner to ${params.cosigner}... this will take a moment`,
    );
    const txHash = await cm.sendTransaction({
      to: config.deployment!.contract_address as Hex,
      data,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);
    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    store.data!.cosigner = params.cosigner;
    store.write();

    printTransactionHash(receipt.transactionHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Error setting cosigner: ${error.message}` });
  }
};
