import 'dotenv/config';
import chalk from 'chalk';
import { Command } from 'commander';
import { deployContract } from './deployContract';
import { loadCollection, loadPrivateKey, loadSigner } from './loaders';
import { showMainTitle } from '../utils/display';
import {
  goToMainMenuOrExit,
  promptForCollectionFile,
  setBaseDir,
} from '../utils/common';

export const mainMenu = async () => {
  setBaseDir();

  showMainTitle();
  await loadSigner();
  console.log('');
  await loadPrivateKey();

  console.log('');
  console.log(chalk.green('Please select a collection configuration file:'));
  console.log('');

  let collectionFile = '';
  if (!process.env.COLLECTION_FILE) {
    collectionFile = await promptForCollectionFile();
    process.env.COLLECTION_FILE = collectionFile;
    loadCollection(collectionFile);
    console.log('');
  }

  const program = new Command();

  program
    .name('magicdrop-cli')
    .description('CLI for managing blockchain contracts and tokens')
    .version('1.0.0');

  program
    .command('deploy')
    .description('Deploy Contracts')
    .action(async () => {
      await deployContract(collectionFile);
    });

  program
    .command('quit')
    .description('Quit the application')
    .action(() => {
      console.log('Exiting...');
      process.exit(0);
    });

  program.parse(process.argv);

  // await goToMainMenuOrExit(mainMenu);
};
