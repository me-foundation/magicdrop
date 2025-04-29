import { encodeFunctionData, Hex } from 'viem';
import { actionPresets } from './common';
import { ERC712M_ABIS } from '../../abis';
import { printTransactionHash, showError, showText } from '../display';
import { TOKEN_STANDARD } from '../constants';
import { ERC721Collection } from '../types';

export const setTokenUriSuffixAction = async (
  symbol: string,
  params: {
    tokenUriSuffix: string;
  },
) => {
  try {
    const { cm, config, store } = await actionPresets(symbol);
    if (config.tokenStandard !== TOKEN_STANDARD.ERC721)
      throw new Error(
        `this action is only supported for ${TOKEN_STANDARD.ERC721} collections.`,
      );

    const data = encodeFunctionData({
      abi: [ERC712M_ABIS.setTokenUriSuffix],
      functionName: ERC712M_ABIS.setTokenUriSuffix.name,
      args: [params.tokenUriSuffix],
    });

    showText('Setting tokenURISuffix... this will take a moment');
    const txHash = await cm.sendTransaction({
      to: config.deployment!.contract_address as Hex,
      data,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);
    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    (store.data as ERC721Collection)!.tokenUriSuffix = params.tokenUriSuffix;
    store.write();

    printTransactionHash(receipt.transactionHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Error setting mintable: ${error.message}` });
  }
};
