import { showError, showText } from '../display';
import { getProjectStore, getWalletStore } from '../fileUtils';
import { createProjectSigner } from '../turnkey';

const newWalletAction = async (
  collection: string,
  params: {
    force?: boolean;
  },
) => {
  collection = collection.toLowerCase();

  const projectStore = getProjectStore(collection, false, true);

  if (!projectStore.exists) {
    showError({ text: `Project ${collection} does not exists` });
    process.exit(1);
  }

  const walletStore = getWalletStore(collection, false, true);
  if (walletStore.exists && !params.force) {
    showError({
      text: `A Wallet file already exists for ${collection}. Use --force to overwrite.`,
    });
    process.exit(1);
  }

  // Create a wallet for the project
  const res = await createProjectSigner(collection);
  const signer = res.signer;

  const signerInfo = `Note: A signer account: "${signer?.address}" was created for this collection, you will need to fund it before you can deploy this collection.`;

  showText(
    `Successfully set up new wallet for ${collection}`,
    `
    wallet: ${res.walletStore.root}

    ${signerInfo}
    `,
    true,
  );
};

export default newWalletAction;
