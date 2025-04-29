import { Hex } from 'viem';
import { ContractManager } from '../ContractManager';
import { setupContract } from '../deployContract';
import { init } from '../evmUtils';
import { getProjectSigner } from '../turnkey';
import { showError } from '../display';
import { verifyContractDeployment } from '../common';

const initContractAction = async (
  symbol: string,
  params: { stagesFile: string },
) => {
  try {
    symbol = symbol.toLowerCase();

    const { store } = init(symbol);
    const config = store.data!;

    verifyContractDeployment(config.deployment?.contract_address);

    const { signer } = await getProjectSigner(symbol);

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
