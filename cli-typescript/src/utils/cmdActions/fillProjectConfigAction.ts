import fs from 'fs';
import { showError, showText } from '../display';
import { EvmPlatform, init, validateConfig } from '../evmUtils';

const fillProjectConfigAction = async (
  platform: EvmPlatform,
  symbol: string,
  params: {
    configFile: string;
  },
) => {
  try {
    symbol = symbol.toLowerCase();

    const { store } = init(symbol);

    if (!!store.data?.deployment) {
      throw new Error('Project already deployed. Cannot fill config.');
    }

    // Read the config file
    if (!fs.existsSync(params.configFile)) {
      throw new Error('Config file does not exist.');
    }

    const config = fs.readFileSync(params.configFile, 'utf-8');
    const projectData = JSON.parse(config);

    delete projectData['deployment'];

    const mergedConfig = {
      ...store.data!,
      ...projectData,
    };

    // validate the project data
    const isValid = validateConfig(platform, mergedConfig);
    if (!isValid) {
      throw new Error(
        'Invalid configuration. Please check your config file and CLI options.',
      );
    }

    store.data = mergedConfig;
    store.write();

    showText(`Successfully updated config for ${symbol}`, '', true);
  } catch (error: any) {
    showError({
      text: `An error occurred while setting up the project ${error.message}`,
    });
    process.exit(1);
  }
};

export default fillProjectConfigAction;
