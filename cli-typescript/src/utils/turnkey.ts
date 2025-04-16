import { ApiKeyStamper } from '@turnkey/api-key-stamper';
import { TurnkeyClient } from '@turnkey/http';
import { createAccount } from '@turnkey/viem';
import { LocalAccount } from 'viem';

export async function getTurnkey(): Promise<{
  turnkey: TurnkeyClient;
  account: LocalAccount;
}> {
  let turnkeyInstance: TurnkeyClient | null = null;
  let turnkeyAccount: LocalAccount | null = null;

  // Validate required environment variables
  validateTurnkeyEnvironmentVariables();

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
}

// Helper function to validate required environment variables
function validateTurnkeyEnvironmentVariables(): void {
  const requiredEnvs = [
    'TURNKEY_ORG_ID',
    'TURNKEY_API_PRIVATE_KEY',
    'TURNKEY_API_PUBLIC_KEY',
    'TURNKEY_WALLET_ADDRESS',
  ];

  console.log('Validating turnkey environment variables...');

  const missingEnvs = requiredEnvs.filter((env) => !process.env[env]);

  if (missingEnvs.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missingEnvs.join(', ')}`,
    );
  }
}
