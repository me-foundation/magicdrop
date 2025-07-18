import { showError, showText } from '../display';
import { getProjectStore } from '../fileUtils';
import { getMETurnkeyServiceClient } from '../turnkey';

const getWalletInfoAction = async (symbol: string) => {
  symbol = symbol.toLowerCase();

  const projectStore = getProjectStore(symbol, false, true);

  if (!projectStore.exists) {
    showError({ text: `Project ${symbol} does not exists` });
    process.exit(1);
  }

  try {
    const meTurnkeyServiceClient = await getMETurnkeyServiceClient();
    const walletInfo = await meTurnkeyServiceClient.getWallet(symbol);
    if (!walletInfo) {
      showError({
        text: `Failed to retrieve wallet information for ${symbol}.`,
      });
      process.exit(1);
    }

    showText('Wallet information retrieved successfully.');
    console.log(walletInfo);
  } catch (error: any) {
    showError({
      text: `Failed to retrieve wallet information for ${symbol}.`,
      subtext: error.message,
    });
    process.exit(1);
  }
};

export default getWalletInfoAction;
