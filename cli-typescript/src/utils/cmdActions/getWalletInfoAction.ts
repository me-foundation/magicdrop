import { showError, showText } from '../display';
import { getProjectStore, getWalletStore } from '../fileUtils';

const getWalletInfoAction = async (symbol: string) => {
  symbol = symbol.toLowerCase();

  const projectStore = getProjectStore(symbol, false, true);

  if (!projectStore.exists) {
    showError({ text: `Project ${symbol} does not exists` });
    process.exit(1);
  }

  const walletStore = getWalletStore(symbol, false, true);
  if (!walletStore.exists) {
    showError({
      text: `A Wallet file does not exists for ${symbol}.`,
    });
    process.exit(1);
  }

  walletStore.read();
  if (!walletStore.data) {
    showError({
      text: `No data found for the wallet of ${symbol}.`,
    });
    process.exit(1);
  }

  showText('Wallet information retrieved successfully.');
  console.log(walletStore.data);
};

export default getWalletInfoAction;
