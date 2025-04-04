import chalk from 'chalk';
import { confirm, input } from '@inquirer/prompts';
import { checkSignerNativeBalance, getExplorerTxUrl, getSymbolFromChainId, promptForConfirmation, setRpcUrl } from './common';
import { TOKEN_STANDARD } from './constants';
import { collapseAddress } from './utils';

export const showMainTitle = () => {
    console.log(chalk.bold.blue('Welcome to MagicDrop CLI'));
    console.log(chalk.blue('=============================='));
};

export const displayMessage = (message: string) => {
    console.log(chalk.green(message));
};

export const displayError = (error: string) => {
    console.error(chalk.red(`Error: ${error}`));
};

export const promptUser = (prompt: string) => {
    return new Promise<string>((resolve) => {
        process.stdout.write(chalk.yellow(`${prompt}: `));
        process.stdin.once('data', (data) => {
            resolve(data.toString().trim());
        });
    });
};

export const printSignerWithBalance = async (chainId: string) => {
    setRpcUrl(chainId);

    const RPC_URL = process.env.RPC_URL;
    const SIGNER = process.env.SIGNER;
    if (!RPC_URL || !SIGNER) {
        throw new Error('RPC_URL or SIGNER environment variable is not set.');
    }

    const balance = checkSignerNativeBalance(chainId, SIGNER, RPC_URL);
    const symbol = getSymbolFromChainId(chainId);

    console.log(`Signer: ${SIGNER}`);
    console.log(`Balance: ${balance} ${symbol}`);
}

/**
 * Formats and displays deployment details, then prompts the user for confirmation.
 * @param details Deployment details including name, symbol, token standard, owner, impl ID, chain ID, and deployment fee.
 * @throws Error if the user does not confirm the deployment.
 */
export const confirmDeployment = async (details: {
    name: string;
    symbol: string;
    tokenStandard: TOKEN_STANDARD;
    initialOwner: string;
    implId: string;
    chainId: string;
    deploymentFee: string;
  }): Promise<void> => {
    const {
      name,
      symbol,
      tokenStandard,
      initialOwner,
      implId,
      chainId,
      deploymentFee,
    } = details;
  
    console.log('');
    console.log('==================== DEPLOYMENT DETAILS ====================');
    console.log(`Name:                         ${name}`);
    console.log(`Symbol:                       ${symbol}`);
    console.log(`Token Standard:               ${tokenStandard}`);
    console.log(`Initial Owner:                ${initialOwner}`);
    console.log(
        `Impl ID:                      ${implId === "0" ? 'DEFAULT' : implId}`
    );
    console.log(`Chain ID:                     ${chainId}`);
    console.log(`Deployment Fee:               ${deploymentFee}`);
    console.log('============================================================');
    console.log('');

    const confirmed = await promptForConfirmation()

    if (!confirmed) {
        console.log('Exiting...');
        throw new Error('Deployment canceled by user.');
    }
};

/**
 * Prints the transaction hash and its corresponding explorer URL.
 * @param output The JSON output from the transaction.
 * @param chainId The chain ID where the transaction occurred.
 * @throws Error if the transaction failed or the output is invalid.
 */
export const printTransactionHash = (output: string, chainId: string): void => {
    try {
        const parsedOutput = JSON.parse(output);
        const txHash = parsedOutput.transactionHash;

        if (!txHash) {
        throw new Error('Transaction hash not found in the output.');
        }

        console.log('');
        console.log('Transaction successful.');
        console.log(getExplorerTxUrl(chainId, txHash));
        console.log('');
    } catch (error) {
        console.error('Transaction failed.');
        throw new Error(error.message || 'Failed to parse transaction output.');
    }
};

/**
 * Displays a styled title and subtitle in the console.
 * @param text The text to display.
 * @param subtext The subtext to display.
 * @param showBorder Whether to show a border around the text.
 * @param boldText Whether to display the text in bold.
 */
export const showText = (text: string, subtext?: string, showBorder = true, boldText = true): void => {
    const border = showBorder ? chalk.hex('#D48CFF')('='.repeat(40)) : "";
    const styledSubtitle = subtext ? chalk.hex('#D48CFF')(subtext) : '';

    let styledTitle = chalk.hex('#D48CFF')(text);
    if (boldText) styledTitle = chalk.bold(styledTitle);
    
    console.log('\n' + border);
    console.log(styledTitle.padStart((40 + styledTitle.length) / 2));
    if (styledSubtitle) console.log(styledSubtitle.padStart((40 + styledSubtitle.length) / 2));
    console.log(border + '\n');
};

/**
 * Displays contract setup details and prompts the user for confirmation.
 * @param setupDetails An object containing all the setup details.
 * @throws Error if the user does not confirm the setup.
 */
export const confirmSetup = async (setupDetails: {
    chainId: string;
    tokenStandard: string;
    contractAddress: string;
    maxMintableSupply: string;
    globalWalletLimit: string;
    mintCurrency: string;
    royaltyReceiver: string;
    royaltyFee: string;
    stagesFile?: string | null;
    stagesJson?: string | null;
    fundReceiver: string;
  }): Promise<void> => {
    const {
      chainId,
      tokenStandard,
      contractAddress,
      maxMintableSupply,
      globalWalletLimit,
      mintCurrency,
      royaltyReceiver,
      royaltyFee,
      stagesFile,
      stagesJson,
      fundReceiver,
    } = setupDetails;

  console.log('\n==================== CONTRACT DETAILS ====================');
  console.log(`Chain:                        ${chainId}`);
  console.log(`Token Standard:               ${tokenStandard}`);
  console.log(`Contract Address:             ${collapseAddress(contractAddress)}`);
  console.log('======================= SETUP INFO =======================');
  console.log(`Max Mintable Supply:          ${maxMintableSupply}`);
  console.log(`Global Wallet Limit:          ${globalWalletLimit}`);
  console.log(`Mint Currency:                ${collapseAddress(mintCurrency)}`);
  console.log(`Royalty Receiver:             ${collapseAddress(royaltyReceiver)}`);
  console.log(`Royalty Fee:                  ${royaltyFee}`);
  console.log(`Stages File:                  ${stagesFile || 'N/A'}`);
  console.log(
    `Stages JSON:                  ${
      stagesJson
        ? `${stagesJson.replace(/\s+/g, '').slice(0, 30)}${
            stagesJson.length > 30 ? '... rest omitted' : ''
          }`
        : 'N/A'
    }`
  );
  console.log(`Fund Receiver:                ${collapseAddress(fundReceiver)}`);
  console.log('==========================================================\n');

  const proceed = await confirm(
    {
      message: 'Do you want to proceed?',
      default: true,
    },
  );

  if (!proceed) {
    console.log('Exiting...');
    throw new Error('Setup process aborted by the user.');
  }
};
