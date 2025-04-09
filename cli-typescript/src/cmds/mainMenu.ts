import 'dotenv/config';
import { Command } from 'commander';
import { loadDefaults, loadPrivateKey } from '../utils/loaders';
import { showError, showMainTitle } from '../utils/display';
import { setBaseDir } from '../utils/setters';
import eth from './eth';
import monad from './monad';

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

export const mainMenu = async () => {
  showMainTitle();

  const program = new Command();

  program
    .name('magicdrop-cli')
    .description('CLI for managing blockchain contracts and tokens')
    .version('2.0.0');

  program.hook('preAction', async () => {
    try {
      await presets();
    } catch (error: any) {
      showError({ text: `setup failed - ${error.message}` });
    }
  });

  // Register sub-commands
  program.addCommand(eth);
  program.addCommand(monad);

  await program.parseAsync(process.argv);
};
