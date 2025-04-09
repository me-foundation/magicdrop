import { Command } from 'commander';
import { getEnvOption, setupContractOption } from './cmdOptions';
import { EvmPlatform } from './evmUtils';
import { supportedChainNames } from './constants';
import deployAction from './cmdActions/deployAction';
import { loadDefaults, loadPrivateKey } from './loaders';
import { setBaseDir } from './setters';
import { showError } from './display';

// drop2 eth deploy <collection> --env sepolia

const presets = async () => {
  try {
    console.log('Starting prestart tasks...');

    setBaseDir();

    // Load default configurations
    await loadDefaults();

    // Check if the default configuration is complete
    if (process.env.DEFAULT_CONFIG_COMPLETE !== 'true') {
      throw new Error(
        'Configuration is incomplete. Please ensure all values are set in defaults.json.',
      );
    }

    await loadPrivateKey();
  } catch (error: any) {
    showError({ text: `An error occurred: ${error.message}` });
    process.exit(1);
  }
};

export const createEvmCommand = ({
  platform,
  commandAliases,
}: {
  platform: EvmPlatform;
  commandAliases: string[];
}) => {
  const newCmd = new Command()
    .name(platform.name.toLowerCase())
    .description(`${platform.name} launchpad commands`)
    .aliases(commandAliases);

  newCmd.hook('preAction', async () => {
    try {
      await presets();
    } catch (error: any) {
      showError({ text: `setup failed - ${error.message}` });
    }
  });

  newCmd
    .command('deploy <collection>')
    .description(
      'Deploys an ERC721 or ERC1155 collection with the given parameters',
    )
    .addOption(
      getEnvOption(
        `Environment to deploy to (e.g., ${Array.from(platform.chainIdsMap.keys())}`,
        supportedChainNames[platform.defaultChain],
      ),
    )
    .addOption(setupContractOption)
    .action(
      async (
        collection: string,
        params: {
          env: string;
          setupContract: 'yes' | 'no' | 'deferred';
        },
      ) => await deployAction(platform, collection, params),
    );

  return newCmd;
};
