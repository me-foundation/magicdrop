import { createAccount } from '@turnkey/viem';
import { Account, Hex } from 'viem';
import {
  TurnkeyApiClient,
  Turnkey as TurnkeySDKServer,
} from '@turnkey/sdk-server';
import { getWalletStore } from './fileUtils';
import { fetchSecretFromAWS } from './common';
import { showText } from './display';

const TURNKEY_SECRET_NAME =
  process.env.ENVIRONMENT === 'PROD'
    ? 'eng-magicdrop-prod'
    : 'eng-magicdrop-dev';
const TURNKEY_BASE_URL = 'https://api.turnkey.com';
const ETHEREUM_WALLET_DEFAULT_PATH = "m/44'/60'/0'/0/0"; // eslint-disable-line quotes
let turnkeySecrets: Record<string, string> | null = null;

/**
 * Fetches and validates Turnkey environment variables from AWS Secrets Manager.
 * @param secretName The name of the AWS Secrets Manager secret.
 * @param otherEnvs Additional environment variables to validate.
 */
const validateTurnkeyEnvironmentVariables = async (
  secretName: string,
  otherEnvs: string[] = [],
): Promise<void> => {
  if (!turnkeySecrets) {
    showText(
      `Fetching Turnkey secrets from AWS Secrets Manager: ${secretName}`,
    );
    turnkeySecrets = await fetchSecretFromAWS(secretName);
  }

  const requiredEnvs = [
    'TURNKEY_ORG_ID',
    'TURNKEY_API_PUBLIC_KEY_SETUP',
    'TURNKEY_API_PRIVATE_KEY_SETUP',
    'TURNKEY_API_PUBLIC_KEY_SIGNER',
    'TURNKEY_API_PRIVATE_KEY_SIGNER',
    ...otherEnvs,
  ];

  const missingEnvs = requiredEnvs.filter((env) => !turnkeySecrets![env]);

  if (missingEnvs.length > 0) {
    throw new Error(
      `Missing required Turnkey environment variables: ${missingEnvs.join(', ')}`,
    );
  }
};

/**
 * Returns a singleton instance of TurnkeyApiClient.
 * Ensures only one instance is created and reused.
 */
export const getTurnkeySignerClient = (() => {
  let turnkeyClientInstance: TurnkeyApiClient | null = null;

  return async (
    orgId?: string,
    refresh?: boolean,
  ): Promise<TurnkeyApiClient> => {
    if (
      !turnkeyClientInstance ||
      refresh ||
      (orgId && turnkeyClientInstance.config.organizationId !== orgId)
    ) {
      await validateTurnkeyEnvironmentVariables(TURNKEY_SECRET_NAME);

      // Create a new TurnkeyClient instance
      const turnkey = new TurnkeySDKServer({
        apiBaseUrl: TURNKEY_BASE_URL,
        apiPublicKey: turnkeySecrets!.TURNKEY_API_PUBLIC_KEY_SIGNER!,
        apiPrivateKey: turnkeySecrets!.TURNKEY_API_PRIVATE_KEY_SIGNER!,
        defaultOrganizationId: orgId ?? turnkeySecrets!.TURNKEY_ORG_ID!,
      });

      turnkeyClientInstance = turnkey.apiClient();
    }

    return turnkeyClientInstance;
  };
})();

export const getTurnkeySetupClient = (() => {
  let turnkeySetupClientInstance: TurnkeyApiClient | null = null;
  return async (refresh?: boolean): Promise<TurnkeyApiClient> => {
    if (!turnkeySetupClientInstance || refresh) {
      await validateTurnkeyEnvironmentVariables(TURNKEY_SECRET_NAME);

      // Create a new TurnkeyClient instance
      const turnkeySetup = new TurnkeySDKServer({
        apiBaseUrl: TURNKEY_BASE_URL,
        apiPublicKey: turnkeySecrets!.TURNKEY_API_PUBLIC_KEY_SETUP!,
        apiPrivateKey: turnkeySecrets!.TURNKEY_API_PRIVATE_KEY_SETUP!,
        defaultOrganizationId: turnkeySecrets!.TURNKEY_ORG_ID!,
      });
      turnkeySetupClientInstance = turnkeySetup.apiClient();
    }
    return turnkeySetupClientInstance;
  };
})();

export const createNewWallet = async (
  walletName: string,
): Promise<{ walletId: string; addresses: string[] }> => {
  try {
    const turnkeyClient = await getTurnkeySignerClient();

    const { walletId, addresses } = await turnkeyClient.createWallet({
      walletName,
      accounts: [
        {
          curve: 'CURVE_SECP256K1',
          pathFormat: 'PATH_FORMAT_BIP32',
          path: ETHEREUM_WALLET_DEFAULT_PATH,
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

export const getSignerAccount = async (
  signer: Hex,
  orgId: string,
): Promise<Account> => {
  const turnkeyClient = await getTurnkeySignerClient(orgId);
  const account = await createAccount({
    client: turnkeyClient,
    organizationId: turnkeyClient.config.organizationId,
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
    const turnkeyClient = await getTurnkeySignerClient(
      walletData.subOrgId,
      true,
    );

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
      signer: await getSignerAccount(address, walletData.subOrgId),
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
    const { walletId, addresses, subOrgId } = await createSecureWallet(
      walletName || projectName,
    );

    if (!addresses?.length || !addresses[0]) {
      throw new Error('Failed to create a signer account.');
    }

    const signer = addresses[0] as Hex;

    walletStore.data = { walletId, signer, subOrgId };
    walletStore.write();

    showText(`New wallet created and saved to ${walletStore.root}`);
    const account = await getSignerAccount(signer, subOrgId);

    return {
      signer: account,
      walletStore,
    };
  } catch (error: any) {
    throw new Error(`Failed to create a new wallet: ${error.message}`);
  }
};

export async function createSecureWallet(
  collectionName: string,
): Promise<{ subOrgId: string; walletId: string; addresses: string[] }> {
  try {
    const setupClient = await getTurnkeySetupClient();

    // Create sub-org
    const subOrg = await setupClient.createSubOrganization({
      subOrganizationName: `${collectionName}-sub-org`,
      rootQuorumThreshold: 1,
      rootUsers: [
        {
          authenticators: [],
          oauthProviders: [],
          userName: 'setup-api-user',
          apiKeys: [
            {
              apiKeyName: 'setup-api-key',
              publicKey: turnkeySecrets!.TURNKEY_API_PUBLIC_KEY_SETUP!,
              curveType: 'API_KEY_CURVE_P256',
            },
          ],
        },
        {
          authenticators: [],
          oauthProviders: [],
          userName: 'signer-api-user',
          apiKeys: [
            {
              apiKeyName: 'signer-api-key',
              publicKey: turnkeySecrets!.TURNKEY_API_PUBLIC_KEY_SIGNER!,
              curveType: 'API_KEY_CURVE_P256',
            },
          ],
        },
      ],
      wallet: {
        walletName: `${collectionName}-wallet`,
        accounts: [
          {
            curve: 'CURVE_SECP256K1',
            pathFormat: 'PATH_FORMAT_BIP32',
            path: ETHEREUM_WALLET_DEFAULT_PATH,
            addressFormat: 'ADDRESS_FORMAT_ETHEREUM',
          },
        ],
      },
    });

    if (!subOrg) {
      throw new Error('Failed to create sub-organization.');
    }

    const [setupUserId, signerUserId] = subOrg.rootUserIds!;
    const wallet = subOrg.wallet!;

    // Attach a signer policy to signer
    await setupClient.createPolicy({
      organizationId: subOrg.subOrganizationId,
      policyName: `Allow signer to sign transactions with ${collectionName}-wallet`,
      effect: 'EFFECT_ALLOW',
      consensus: `approvers.any(user, user.id == '${signerUserId!}')`,
      condition: `activity.type == 'ACTIVITY_TYPE_SIGN_TRANSACTION_V2' && wallet.id == '${wallet.walletId}'`,
      notes: `Allow signer: ${signerUserId!} to sign transactions with wallet: ${wallet.walletId}`,
    });

    // Remove signer from root quorum
    setupClient.updateRootQuorum({
      organizationId: subOrg.subOrganizationId,
      threshold: 1,
      userIds: [setupUserId!],
    });

    showText(`✅ Wallet for ${collectionName} created and saved securely.`);
    return {
      walletId: wallet.walletId,
      addresses: wallet.addresses,
      subOrgId: subOrg.subOrganizationId,
    };
  } catch (error: any) {
    throw new Error(`Failed to create a new wallet: ${error.message}`);
  }
}
