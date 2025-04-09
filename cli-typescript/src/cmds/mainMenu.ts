import 'dotenv/config';
import { Command } from 'commander';
import { showMainTitle } from '../utils/display';
import eth from './eth';
import monad from './monad';
import { listProjectsCmd, newProjectCmd } from './general';

export const mainMenu = async () => {
  showMainTitle();

  const program = new Command();

  program
    .name('magicdrop-cli')
    .description('CLI for managing blockchain contracts and tokens')
    .version('2.0.0');

  // Register sub-commands
  program.addCommand(newProjectCmd);
  program.addCommand(listProjectsCmd);
  program.addCommand(eth);
  program.addCommand(monad);

  await program.parseAsync(process.argv);
};
