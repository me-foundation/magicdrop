import { Command } from 'commander';
import {
  getEnvOption,
  setupContractOption,
  setupWalletOption,
  tokenStandardOption,
  totalTokensOption,
} from './cmdOptions';
import { EvmPlatform } from './evmUtils';
import deployAction from './cmdActions/deployAction';
import { loadDefaults } from './loaders';
import { setBaseDir } from './setters';
import { showError } from './display';
import {
  COLLECTION_DIR,
  supportedChainNames,
  TOKEN_STANDARD,
} from './constants';
import newProjectAction from './cmdActions/newProjectAction';

export const getNewProjectCmdDescription = (defaultInfo?: string) => {
  defaultInfo =
    defaultInfo ||
    'The default chain is monad testnet and the default token standard is ERC721.';
  return `
    Creates a new launchpad/collection template. 
    you can specify the collection directory by setting the "MAGIC_DROP_COLLECTION_DIR" env 
    else it defaults to "${COLLECTION_DIR}" in the project directory.
    You can also specify the chain and token standard to use for the new project.
    ${defaultInfo}
  `;
};

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
    .command('new <collection>')
    .aliases(['n', 'init'])
    .description(
      getNewProjectCmdDescription(
        `The default environment is ${platform.defaultChain} and the default token standard is ERC721.`,
      ),
    )
    .addOption(
      getEnvOption(
        Array.from(platform.chainIdsMap.keys()),
        'Environment to deploy to',
        platform.defaultChain,
      ),
    )
    .addOption(tokenStandardOption)
    .addOption(setupWalletOption)
    .action(
      async (
        collection: string,
        params: {
          env: string;
          tokenStandard: TOKEN_STANDARD;
          setupWallet: boolean;
        },
      ) =>
        await newProjectAction(collection, {
          chain:
            supportedChainNames[
              platform.chainIdsMap.get(params.env) ??
                platform.chainIdsMap.get(platform.defaultChain)!
            ],
          tokenStandard: params.tokenStandard,
          setupWallet: params.setupWallet,
        }),
    );

  newCmd
    .command('deploy <collection>')
    .description(
      'Deploys an ERC721 or ERC1155 collection with the given parameters',
    )
    .addOption(
      getEnvOption(
        Array.from(platform.chainIdsMap.keys()),
        'Environment to deploy to',
        platform.defaultChain,
      ),
    )
    .addOption(setupContractOption)
    .addOption(totalTokensOption)
    .action(
      async (
        collection: string,
        params: {
          env: string;
          setupContract: 'yes' | 'no' | 'deferred';
          totalTokens: number;
        },
      ) => await deployAction(platform, collection, params),
    );

  return newCmd;
};
