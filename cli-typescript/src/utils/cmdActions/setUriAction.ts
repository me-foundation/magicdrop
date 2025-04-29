import { encodeFunctionData, Hex, isAddress } from 'viem';
import { init } from '../evmUtils';
import { ContractManager } from '../ContractManager';
import { getProjectSigner } from '../turnkey';
import { ERC1155M_ABIS, ERC712M_ABIS } from '../../abis';
import { TOKEN_STANDARD } from '../constants';
import { printTransactionHash, showText } from '../display';

export const setUriAction = async (collection: string, uri: string) => {
  try {
    collection = collection.toLowerCase();

    const { store } = init(collection);
    const config = store.data!;

    if (!config.deployment || !isAddress(config.deployment.contract_address)) {
      throw Error(
        'Invalid or missing collection address. Please deploy the contract first.',
      );
    }

    const { signer } = await getProjectSigner(collection);

    const cm = new ContractManager(config.chainId, signer);

    let data: Hex;

    if (config.tokenStandard === TOKEN_STANDARD.ERC721) {
      showText(`Setting base URI for ${config.tokenStandard} collection...`);

      data = encodeFunctionData({
        abi: [ERC712M_ABIS.setBaseUri],
        functionName: ERC712M_ABIS.setBaseUri.name,
        args: [uri],
      });
    } else if (config.tokenStandard === TOKEN_STANDARD.ERC1155) {
      showText(`Setting URI for ${config.tokenStandard} collection...`);
      data = encodeFunctionData({
        abi: [ERC1155M_ABIS.setUri],
        functionName: ERC1155M_ABIS.setUri.name,
        args: [uri],
      });
    } else {
      throw new Error('Unsupported token standard. Please check the config.');
    }

    const txHash = await cm.sendTransaction({
      to: config.deployment.contract_address,
      data,
    });
    const receipt = await cm.waitForTransactionReceipt(txHash);

    if (receipt.status !== 'success') {
      throw new Error('Transaction failed');
    }

    store.data!.uri = uri;
    store.write();

    printTransactionHash(txHash, config.chainId);
  } catch (error: any) {
    console.error('Error setting URI:', error.message);
  }
};

export default setUriAction;
