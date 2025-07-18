import { encodeFunctionData, Hex } from 'viem';
import { ERC1155M_ABIS, ERC712M_ABIS } from '../../abis';
import { TOKEN_STANDARD } from '../constants';
import { printTransactionHash, showText } from '../display';
import { actionPresets } from './common';

export const setUriAction = async (symbol: string, params: { uri: string }) => {
  try {
    const { config, cm, store } = await actionPresets(symbol);

    let data: Hex;

    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      showText(`Setting base URI for ${config.tokenStandard} collection...`);

      data = encodeFunctionData({
        abi: [ERC712M_ABIS.setBaseUri],
        functionName: ERC712M_ABIS.setBaseUri.name,
        args: [params.uri],
      });
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      showText(`Setting URI for ${config.tokenStandard} collection...`);
      data = encodeFunctionData({
        abi: [ERC1155M_ABIS.setUri],
        functionName: ERC1155M_ABIS.setUri.name,
        args: [params.uri],
      });
    } else {
      throw new Error('Unsupported token standard. Please check the config.');
    }

    const txHash = await cm.sendTransaction({
      to: config.deployment?.contract_address as Hex,
      data,
    });
    const receipt = await cm.waitForTransactionReceipt(txHash);

    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    store.data!.uri = params.uri;
    store.write();

    printTransactionHash(txHash, config.chainId);
  } catch (error: any) {
    console.error('Error setting URI:', error.message);
  }
};

export default setUriAction;
