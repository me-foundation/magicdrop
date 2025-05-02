import { TOKEN_STANDARD } from '../constants';
import { showError, showText } from '../display';
import { getProjectStore } from '../fileUtils';
import { getChainIdFromName } from '../getters';
import { ERC1155_TEMPLATE, ERC721_TEMPLATE } from '../templates';
import { createProjectSigner } from '../turnkey';
import { Collection } from '../types';

const newProjectAction = async (
  symbol: string,
  params: {
    tokenStandard: TOKEN_STANDARD;
    chain: string;
    setupWallet: boolean;
  },
) => {
  symbol = symbol.toLowerCase();

  const projectStore = getProjectStore(symbol, false, true);

  if (projectStore.exists) {
    showError({ text: `Project ${symbol} already exists` });
    process.exit(1);
  }

  projectStore.data = projectStore.data = (
    params.tokenStandard === TOKEN_STANDARD.ERC721
      ? ERC721_TEMPLATE
      : ERC1155_TEMPLATE
  ) as Collection;

  if (projectStore.data) {
    projectStore.data.chainId = getChainIdFromName(params.chain);
    projectStore.write();
  }

  let walletFilePath = 'N/A';
  let signer = undefined;

  // Create a wallet for the project
  if (params.setupWallet) {
    const res = await createProjectSigner(symbol);
    walletFilePath = res.walletStore.root;
    signer = res.signer;
  }

  const signerInfo = params.setupWallet
    ? `Note: A signer account - "${signer?.address}" - was created for this collection, you will need to fund it before you can deploy this collection.`
    : `Note: A signer account was NOT setup for this collection, you will need one before you can deploy.
      You can use the create-wallet command to create a signer account for this collection OR 
      You can do this manually by creating a wallet.json file in the directory: ${projectStore.storeDir}.`;

  showText(
    `Successfully set up new project for ${symbol}`,
    `
    path: ${projectStore.root}
    wallet: ${walletFilePath}

    ${signerInfo}
    `,
    true,
  );
};

export default newProjectAction;
