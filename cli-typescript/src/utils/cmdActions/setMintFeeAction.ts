import { Hex } from 'viem';
import { ContractManager } from '../ContractManager';
import { parseMintFee, setMintFee } from '../deployContract';
import { init } from '../evmUtils';
import { getProjectSigner } from '../turnkey';
import { showError } from '../display';
import { verifyContractDeployment } from '../common';

const setMintFeeAction = async (
  symbol: string,
  params: { mintFee: number },
) => {
  try {
    symbol = symbol.toLowerCase();

    const { store } = init(symbol);
    const config = store.data!;

    verifyContractDeployment(config.deployment?.contract_address);

    const { signer } = await getProjectSigner(symbol);

    const cm = new ContractManager(config.chainId, signer, symbol);

    await setMintFee({
      cm,
      contractAddress: config.deployment!.contract_address as Hex,
      mintFee: parseMintFee(params.mintFee.toString()),
    });
  } catch (error: any) {
    showError({ text: `Error initializing contract: ${error.message}` });
    process.exit(1);
  }
};

export default setMintFeeAction;
