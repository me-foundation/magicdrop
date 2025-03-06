#!/usr/bin/env bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

# Note: Update the contract in the deploy script if you want to deploy a different version. Default is 1_0_0

source ./utils

# Exit on error
set -e

# Initialize variables with environment values
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""
STANDARD=""
IS_ERC721C=false #optional
IMPL_EXPECTED_ADDRESS=""
IMPL_SALT=""
NAME=""
SYMBOL=""
TOKEN_URI_SUFFIX=""
MAX_MINTABLE_SUPPLY="1000"
GLOBAL_WALLET_LIMIT="0"
COSIGNER="0x0000000000000000000000000000000000000000"
TIMESTAMP_EXPIRY_SECONDS="60"
MINT_CURRENCY="0x0000000000000000000000000000000000000000"
FUND_RECEIVER=""
INITIAL_OWNER=""

# Function to display usage
usage() {
    # Example Usage: ./2a-deploy-magicdrop-impl.sh --chain-id 137 --token-standard ERC721 --is-erc721c true --expected-address 0x0000000000000000000000000000000000000000 --salt 0x0000000000000000000000000000000000000000000000000000000000000000
    echo "Usage: $0 --chain-id <chain id> --token-standard <token standard> --is-erc721c <bool> --expected-address <expected address> --salt <salt> --name <name> --symbol <symbol> --fund-receiver <fund receiver address> --uri <token uri suffix> --maxMintableSupply <max mintable supply> --globalWalletLimit <global wallet limit> --cosigner <cosigner address> --timestamp-expiry <timestamp expiry seconds> --mint-currency <mint currency address> --initial-owner <initial owner address>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --token-standard) STANDARD=$2; shift ;;
        --is-erc721c) IS_ERC721C=$2; shift ;;
        --expected-address) IMPL_EXPECTED_ADDRESS=$2; shift ;;
        --salt) IMPL_SALT=$2; shift ;;
        --name) NAME=$2; shift ;;
        --symbol) SYMBOL=$2; shift ;;
        --uri) TOKEN_URI_SUFFIX=$2; shift ;;
        --maxMintableSupply) MAX_MINTABLE_SUPPLY=$2; shift ;;
        --globalWalletLimit) GLOBAL_WALLET_LIMIT=$2; shift ;;
        --cosigner) COSIGNER=$2; shift ;;
        --timestamp-expiry) TIMESTAMP_EXPIRY_SECONDS=$2; shift ;;
        --mint-currency) MINT_CURRENCY=$2; shift ;;
        --fund-receiver) FUND_RECEIVER=$2; shift ;;
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$STANDARD" ] || [ -z "$IMPL_EXPECTED_ADDRESS" ] || [ -z "$IMPL_SALT" ] || [ -z "$NAME" ] || [ -z "$SYMBOL" ] || [ -z "$TOKEN_URI_SUFFIX" ] || [ -z "$MAX_MINTABLE_SUPPLY" ] || [ -z "$GLOBAL_WALLET_LIMIT" ] || [ -z "$COSIGNER" ] || [ -z "$TIMESTAMP_EXPIRY_SECONDS" ] || [ -z "$MINT_CURRENCY" ] || [ -z "$FUND_RECEIVER" ] || [ -z "$INITIAL_OWNER" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

# Convert STANDARD to lowercase for the path
STANDARD_LOWERCASE=$(echo $STANDARD | tr '[:upper:]' '[:lower:]')

echo ""
echo "==================== DEPLOYMENT DETAILS ===================="
echo "Chain ID:                     $CHAIN_ID"
echo "RPC URL:                      $RPC_URL"
echo "Token Standard:               $STANDARD"
echo "Is ERC721C:                   $IS_ERC721C"
echo "Expected Address:             $IMPL_EXPECTED_ADDRESS"
echo "Salt:                         $IMPL_SALT"
echo "Name:                         $NAME"
echo "Symbol:                       $SYMBOL"
echo "Token URI Suffix:             $TOKEN_URI_SUFFIX"
echo "Max Mintable Supply:          $MAX_MINTABLE_SUPPLY"
echo "Global Wallet Limit:          $GLOBAL_WALLET_LIMIT"
echo "Cosigner:                     $COSIGNER"
echo "Timestamp Expiry:             $TIMESTAMP_EXPIRY_SECONDS"
echo "Mint Currency:                $MINT_CURRENCY"
echo "Fund Reciever:                $FUND_RECEIVER"
echo "Initial Owner:                $INITIAL_OWNER"
echo "============================================================"
echo ""
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

echo ""
echo "============= DEPLOYING MAGICDROP IMPLEMENTATION ============="
echo ""

# remove --verify when deploying on Sei Chain. You will need to verify manually.
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL TOKEN_STANDARD=$STANDARD IS_ERC721C=$IS_ERC721C IMPL_EXPECTED_ADDRESS=$IMPL_EXPECTED_ADDRESS IMPL_SALT=$IMPL_SALT NAME=$NAME SYMBOL=$SYMBOL TOKEN_URI_SUFFIX=$TOKEN_URI_SUFFIX MAX_MINTABLE_SUPPLY=$MAX_MINTABLE_SUPPLY GLOBAL_WALLET_LIMIT=$GLOBAL_WALLET_LIMIT COSIGNER=$COSIGNER TIMESTAMP_EXPIRY_SECONDS=$TIMESTAMP_EXPIRY_SECONDS MINT_CURRENCY=$MINT_CURRENCY FUND_RECEIVER=$FUND_RECEIVER INITIAL_OWNER=$INITIAL_OWNER forge script ./DeployMagicDropImplementationDirect.s.sol:DeployMagicDropImplementationDirect \
  --rpc-url $RPC_URL \
  --broadcast \
  --optimizer-runs 777 \
  --via-ir \
  --verify \
  -v

echo ""
echo "============= DEPLOYED MAGICDROP IMPLEMENTATION ============="
echo ""