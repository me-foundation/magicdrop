import { Hex, isAddress } from 'viem';
import { ContractManager } from '../ContractManager';
import { setupContract } from '../deployContract';
import { init } from '../evmUtils';
import { getProjectSigner } from '../turnkey';
import { showError } from '../display';

const initContractAction = async (
  collection: string,
  params: { stagesFile: string },
) => {
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

    await setupContract({
      cm,
      ...config,
      stagesJson: JSON.stringify(config.stages),
      stagesFile: params.stagesFile,
      contractAddress: config.deployment!.contract_address as Hex,
      collectionFile: store.root,
      signer: signer.address,
    });
  } catch (error: any) {
    showError({ text: `Error initializing contract: ${error.message}` });
    process.exit(1);
  }
};

export default initContractAction;
