import { ContractManager } from '../ContractManager';
import { deployContract } from '../deployContract';
import { showError } from '../display';
import { EvmPlatform, init, validateConfig } from '../evmUtils';
import { getProjectSigner } from '../turnkey';

const deployAction = async (
  platform: EvmPlatform,
  symbol: string,
  params: {
    env: string;
    setupContract: 'yes' | 'no' | 'deferred';
    totalTokens?: number;
    stagesFile?: string;
  },
) => {
  try {
    const { env, ...cliOptions } = params;

    const { store } = init(symbol);

    // Step 2: Override config file with CLI flag options if provided
    const mergedConfig = {
      ...store.data!,
      ...cliOptions,
    };

    // validate config
    const isValid = validateConfig(
      platform,
      mergedConfig,
      cliOptions.setupContract === 'yes',
      cliOptions.totalTokens,
    );

    if (!isValid) {
      throw new Error(
        'Invalid configuration. Please check your config file and CLI options.',
      );
    }

    const { signer } = await getProjectSigner(symbol);

    const cm = new ContractManager(mergedConfig.chainId, signer);

    await deployContract({
      ...mergedConfig,
      setupContractOption: cliOptions.setupContract,
      contractManager: cm,
      store,
    });

    console.log('Contract deployed successfully!');
  } catch (error: any) {
    showError({ text: `Error deploying contract: ${error.message}` });
    process.exit(1);
  }
};

export default deployAction;
