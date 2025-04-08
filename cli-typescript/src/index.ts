import { loadDefaults } from './cmds/loaders';
import { mainMenu } from './cmds/mainMenu';
import { setBaseDir } from './utils/common';
import 'dotenv/config';

(async () => {
  try {
    // Load default configurations
    await setBaseDir();
    await loadDefaults();

    // Check if the configuration is complete
    if (process.env.CONFIG_COMPLETE === 'true') {
      console.log('Starting prestart tasks...');
      // Add any prestart logic here if needed
      console.log('Launching main menu...');
      await mainMenu();
    } else {
      console.error(
        'Configuration is incomplete. Please ensure all values are set in defaults.json.',
      );
    }
  } catch (error: any) {
    console.error('An error occurred:', error.message);
    process.exit(1);
  }
})();
