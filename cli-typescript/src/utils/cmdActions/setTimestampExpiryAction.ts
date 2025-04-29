import { encodeFunctionData, Hex } from 'viem';
import { actionPresets } from './common';
import { ERC712M_ABIS } from '../../abis';
import { printTransactionHash, showError, showText } from '../display';
import { TOKEN_STANDARD } from '../constants';

export const setTimestampExpiryAction = async (
  collection: string,
  params: {
    expiry: number;
  },
) => {
  try {
    const { cm, config } = await actionPresets(collection);
    if (config.tokenStandard !== TOKEN_STANDARD.ERC721)
      throw new Error(
        `this action is only supported for ${TOKEN_STANDARD.ERC721} collections`,
      );

    // Validate timestamp as a valid date
    if (
      isNaN(params.expiry) ||
      params.expiry.toString().length !== 10 || // Check if it's in seconds
      new Date(params.expiry * 1000).toString() === 'Invalid Date' // Multiply by 1000 to validate as seconds
    ) {
      throw new Error('timestamp must be a valid Unix timestamp in seconds');
    }

    const data = encodeFunctionData({
      abi: [ERC712M_ABIS.setTimestampExpirySeconds],
      functionName: ERC712M_ABIS.setTimestampExpirySeconds.name,
      args: [params.expiry],
    });

    showText(
      `Setting cosigner signature expiry timestamp to ${params.expiry}... this will take a moment`,
    );
    const txHash = await cm.sendTransaction({
      to: config.deployment!.contract_address as Hex,
      data,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);
    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    printTransactionHash(receipt.transactionHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Error setting expiry: ${error.message}` });
  }
};
