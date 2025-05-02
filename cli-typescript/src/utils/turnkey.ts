import { ApiKeyStamper } from '@turnkey/api-key-stamper';
import { TurnkeyClient } from '@turnkey/http';
import { createAccount } from '@turnkey/viem';
import { Account, Hex } from 'viem';
import {
  TurnkeyApiClient,
  Turnkey as TurnkeySDKServer,
} from '@turnkey/sdk-server';
import { getWalletStore } from './fileUtils';

export const getTurnkey = async (): Promise<{
  turnkey: TurnkeyClient;
  account: Account;
}> => {
  let turnkeyInstance: TurnkeyClient | null = null;
  let turnkeyAccount: Account | null = null;

  // Validate required environment variables
  validateTurnkeyEnvironmentVariables(['TURNKEY_WALLET_ADDRESS']);

  if (!turnkeyInstance) {
    turnkeyInstance = new TurnkeyClient(
      {
        baseUrl: 'https://api.turnkey.com',
      },

      new ApiKeyStamper({
        apiPublicKey: process.env.TURNKEY_API_PUBLIC_KEY!,
        apiPrivateKey: process.env.TURNKEY_API_PRIVATE_KEY!,
      }),
    );
  }

  if (!turnkeyAccount) {
    turnkeyAccount = await createAccount({
      client: turnkeyInstance,
      organizationId: process.env.TURNKEY_ORG_ID!,
      signWith: process.env.TURNKEY_WALLET_ADDRESS!,
    });
  }

  return { turnkey: turnkeyInstance, account: turnkeyAccount };
};

// Helper function to validate required environment variables
const validateTurnkeyEnvironmentVariables = (
  otherEnvs: string[] = [],
): void => {
  const requiredEnvs = [
    'TURNKEY_ORG_ID',
    'TURNKEY_API_PRIVATE_KEY',
    'TURNKEY_API_PUBLIC_KEY',
    ...otherEnvs,
  ];

  console.log('Validating turnkey environment variables...');

  const missingEnvs = requiredEnvs.filter((env) => !process.env[env]);

  if (missingEnvs.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missingEnvs.join(', ')}`,
    );
  }
};

let turnkeyClientInstance: TurnkeyApiClient | null = null;

/**
 * Returns a singleton instance of TurnkeyApiClient.
 * Ensures only one instance is created and reused.
 */
export const getTurnkeyClient = (): TurnkeyApiClient => {
  if (!turnkeyClientInstance) {
    validateTurnkeyEnvironmentVariables();

    // Create a new TurnkeyClient instance
    const turnkey = new TurnkeySDKServer({
      apiBaseUrl: 'https://api.turnkey.com',
      apiPublicKey: process.env.TURNKEY_API_PUBLIC_KEY!,
      apiPrivateKey: process.env.TURNKEY_API_PRIVATE_KEY!,
      defaultOrganizationId: process.env.TURNKEY_ORG_ID!,
    });

    turnkeyClientInstance = turnkey.apiClient();
  }

  return turnkeyClientInstance;
};

const createNewWallet = async (
  walletName: string,
): Promise<{ walletId: string; addresses: string[] }> => {
  try {
    const turnkeyClient = getTurnkeyClient();

    const { walletId, addresses } = await turnkeyClient.createWallet({
      walletName,
      accounts: [
        {
          curve: 'CURVE_SECP256K1',
          pathFormat: 'PATH_FORMAT_BIP32',
          path: "m/44'/60'/0'/0/0", // eslint-disable-line quotes
          addressFormat: 'ADDRESS_FORMAT_ETHEREUM',
        },
      ],
    });

    if (!walletId) {
      throw new Error('Failed to create a new wallet.');
    }

    return { walletId, addresses };
  } catch (error: any) {
    throw new Error(`Failed to create a new Ethereum wallet: ${error.message}`);
  }
};

export const getSignerAccount = async (signer: Hex): Promise<Account> => {
  const turnkeyClient = getTurnkeyClient();
  const account = await createAccount({
    client: turnkeyClient,
    organizationId: process.env.TURNKEY_ORG_ID!,
    signWith: signer,
  });

  if (!account) {
    throw new Error('Failed to retrieve the signer account.');
  }

  return account;
};

export const getProjectSigner = async (
  projectName: string,
): Promise<{ signer: Account }> => {
  try {
    const walletStore = getWalletStore(projectName, false, true);
    // Read the wallet.json file
    const walletData = walletStore.read();

    if (!walletData?.walletId || !walletData?.signer) {
      throw new Error(
        'Invalid wallet.json format. Missing walletId or address.',
      );
    }

    // Verify the walletId and address with the Turnkey API
    const turnkeyClient = getTurnkeyClient();

    const {
      account: { address, walletId },
    } = await turnkeyClient.getWalletAccount({
      walletId: walletData.walletId,
      address: walletData.signer,
    });

    if (address !== walletData.signer || walletId !== walletData.walletId) {
      throw new Error('Wallet ID and address do not match with Turnkey API.');
    }

    // Return the signer/address
    return {
      signer: await getSignerAccount(address),
    };
  } catch (error: any) {
    throw new Error(`Failed to fetch signer: ${error.message}`);
  }
};

export const createProjectSigner = async (
  projectName: string,
  walletName?: string,
): Promise<{
  signer: Account;
  walletStore: ReturnType<typeof getWalletStore>;
}> => {
  const walletStore = getWalletStore(projectName, false, true);

  // create a new wallet
  try {
    const { walletId, addresses } = await createNewWallet(
      walletName || projectName,
    );

    if (!addresses?.length || !addresses[0]) {
      throw new Error('Failed to create a signer account.');
    }

    const signer = addresses[0] as Hex;

    walletStore.data = { walletId, signer };
    walletStore.write();

    console.log(`New wallet created and saved to ${walletStore.root}`);
    const account = await getSignerAccount(signer);

    // Return the signer/address
    return {
      signer: account,
      walletStore,
    };
  } catch (error: any) {
    throw new Error(`Failed to create a new wallet: ${error.message}`);
  }
};
