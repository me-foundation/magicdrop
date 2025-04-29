import { encodeFunctionData, Hex } from 'viem';
import { TOKEN_STANDARD } from '../constants';
import { actionPresets } from './common';
import { ERC1155M_ABIS, ERC712M_ABIS } from '../../abis';
import { printTransactionHash, showError } from '../display';

export const setGlobalWalletLimitAction = async (
  symbol: string,
  params: {
    tokenId?: number;
    globalWalletLimit: number;
  },
) => {
  try {
    const { cm, config, store } = await actionPresets(symbol);
    if (isNaN(params.globalWalletLimit))
      throw new Error('globalWalletLimit must be a number');

    const globalWalletLimit = Number(params.globalWalletLimit);

    let data: Hex;

    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      data = encodeFunctionData({
        abi: [ERC712M_ABIS.setGlobalWalletLimit],
        functionName: ERC712M_ABIS.setGlobalWalletLimit.name,
        args: [BigInt(globalWalletLimit)],
      });
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      if (params.tokenId === undefined || isNaN(params.tokenId))
        throw Error(
          `The tokenId is required for ${TOKEN_STANDARD.ERC1155} contract.`,
        );

      data = encodeFunctionData({
        abi: [ERC1155M_ABIS.setGlobalWalletLimit],
        functionName: ERC1155M_ABIS.setGlobalWalletLimit.name,
        args: [BigInt(params.tokenId), BigInt(globalWalletLimit)],
      });
    } else {
      throw new Error('Unsupported token standard. Please check the config.');
    }

    const txHash = await cm.sendTransaction({
      to: config.deployment!.contract_address as Hex,
      data,
    });

    const receipt = await cm.waitForTransactionReceipt(txHash);
    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      store.data!.globalWalletLimit = globalWalletLimit;
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      (store.data!.globalWalletLimit as number[])[params.tokenId!] =
        globalWalletLimit;
    }
    store.write();

    printTransactionHash(receipt.transactionHash, config.chainId);
  } catch (error: any) {
    showError({ text: `Error setting global wallet limit: ${error.message}` });
  }
};
