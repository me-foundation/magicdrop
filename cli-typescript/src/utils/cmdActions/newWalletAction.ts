import { showError, showText } from '../display';
import { getProjectStore, getWalletStore } from '../fileUtils';
import { createProjectSigner } from '../turnkey';

const newWalletAction = async (
  symbol: string,
  params: {
    force?: boolean;
  },
) => {
  symbol = symbol.toLowerCase();

  const projectStore = getProjectStore(symbol, false, true);

  if (!projectStore.exists) {
    showError({ text: `Project ${symbol} does not exists` });
    process.exit(1);
  }

  const walletStore = getWalletStore(symbol, false, true);
  if (walletStore.exists && !params.force) {
    showError({
      text: `A Wallet file already exists for ${symbol}. Use --force to overwrite.`,
    });
    process.exit(1);
  }

  const walletName = params.force ? `${symbol}-${Date.now()}` : symbol;

  // Create a wallet for the project
  const res = await createProjectSigner(symbol, walletName);
  const signer = res.signer;

  const signerInfo = `Note: A signer account: "${signer?.address}" was created for this collection, you will need to fund it before you can deploy this collection.`;

  showText(
    `Successfully set up new wallet for ${symbol}`,
    `
    wallet: ${res.walletStore.root}

    ${signerInfo}
    `,
    true,
  );
};

export default newWalletAction;
