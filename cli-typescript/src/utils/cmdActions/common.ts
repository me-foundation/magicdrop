import { verifyContractDeployment } from '../common';
import { ContractManager } from '../ContractManager';
import { init } from '../evmUtils';
import { getProjectSigner } from '../turnkey';

export const actionPresets = async (
  symbol: string,
  verifyDeployment: boolean = true,
) => {
  symbol = symbol.toLowerCase();

  const { store } = init(symbol);
  const config = store.data!;

  if (verifyDeployment)
    verifyContractDeployment(config.deployment?.contract_address);

  const { signer } = await getProjectSigner(symbol);

  const cm = new ContractManager(config.chainId, signer);

  await cm.printSignerWithBalance();

  return { signer, cm, store, config };
};
