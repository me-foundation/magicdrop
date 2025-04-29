import { verifyContractDeployment } from '../common';
import { ContractManager } from '../ContractManager';
import { init } from '../evmUtils';
import { getProjectSigner } from '../turnkey';

export const actionPresets = async (
  collection: string,
  verifyDeployment: boolean = true,
) => {
  collection = collection.toLowerCase();

  const { store } = init(collection);
  const config = store.data!;

  if (verifyDeployment)
    verifyContractDeployment(config.deployment?.contract_address);

  const { signer } = await getProjectSigner(collection);

  const cm = new ContractManager(config.chainId, signer);

  await cm.printSignerWithBalance();

  return { signer, cm, store, config };
};
