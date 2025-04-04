import 'dotenv/config';
import { Command } from 'commander';
import { deployContract } from './deployContract';
import { manageContracts } from './manageContracts';
import { tokenOperations } from './tokenOperations';
import { loadPrivateKey } from './loaders';
import { showMainTitle } from '../utils/display';
import { setBaseDir } from '../utils/common';

export const mainMenu = async () => {
  setBaseDir();
  await loadPrivateKey();

  const program = new Command();

  program
    .name('magicdrop-cli')
    .description('CLI for managing blockchain contracts and tokens')
    .version('1.0.0');

  showMainTitle();

  program
    .command('deploy')
    .description('Deploy Contracts')
    .action(() => {
      deployContract();
    });

  //   program
  //     .command('manage')
  //     .description('Manage Contracts')
  //     .action(() => {
  //       manageContracts();
  //     });

  //   program
  //     .command('token')
  //     .description('Token Operations')
  //     .action(() => {
  //       tokenOperations();
  //     });

  //   program
  //     .command('load')
  //     .description('Load Collection Config')
  //     .action(() => {
  //       const collectionFile = loadCollection();
  //       console.log(`Loaded collection from ${collectionFile}`);
  //     });

  //   program
  //     .command('quit')
  //     .description('Quit the application')
  //     .action(() => {
  //       console.log('Exiting...');
  //       process.exit(0);
  //     });

  program.parse(process.argv);
};
