import { Command } from 'commander';
import { showMainTitle } from '../utils/display';
import { createNewWalletCmd, listProjectsCmd, newProjectCmd } from './general';
import {
  abstract,
  apechain,
  arbitrum,
  avalanche,
  base,
  berachain,
  bsc,
  eth,
  monad,
  polygon,
  sei,
} from './networks';

export const mainMenu = async () => {
  showMainTitle();

  const program = new Command();

  program
    .name('magicdrop-cli')
    .description('CLI for managing blockchain contracts and tokens')
    .version('2.0.0');

  // Register sub-commands
  program.addCommand(newProjectCmd);
  program.addCommand(createNewWalletCmd);
  program.addCommand(listProjectsCmd);
  program.addCommand(eth);
  program.addCommand(polygon);
  program.addCommand(bsc);
  program.addCommand(base);
  program.addCommand(sei);
  program.addCommand(apechain);
  program.addCommand(berachain);
  program.addCommand(arbitrum);
  program.addCommand(abstract);
  program.addCommand(avalanche);
  program.addCommand(monad);

  await program.parseAsync(process.argv);
};
