import { showError, showText } from '../display';
import { getProjectStore } from '../fileUtils';
import { getMETurnkeyServiceClient } from '../turnkey';

const newWalletAction = async (symbol: string) => {
  symbol = symbol.toLowerCase();

  const projectStore = getProjectStore(symbol, false, true);

  if (!projectStore.exists) {
    showError({ text: `Project ${symbol} does not exists` });
    process.exit(1);
  }

  const meTurnkeyServiceClient = await getMETurnkeyServiceClient();

  try {
    const walletInfo = await meTurnkeyServiceClient.getWallet(symbol);
    if (walletInfo) {
      showError({
        text: `A Wallet already exists for ${symbol}.`,
      });
      process.exit(1);
    }
  } catch {}

  // Create a wallet for the project
  try {
    const walletInfo = await meTurnkeyServiceClient.createWallet(symbol);

    const signerInfo = `Note: A signer account: "${walletInfo.address}" was created for this collection, you will need to fund it before you can deploy this collection.`;

    showText(
      `Successfully set up new wallet for ${symbol}`,
      `
    walletInfo: ${JSON.stringify(walletInfo, null, 2)}

    ${signerInfo}
    `,
      true,
    );
  } catch (error: any) {
    showError({
      text: `Failed to create a new wallet for ${symbol}: ${error.message}`,
    });
    process.exit(1);
  }
};

export default newWalletAction;
