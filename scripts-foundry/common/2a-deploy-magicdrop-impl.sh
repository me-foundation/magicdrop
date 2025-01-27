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
IMPL_EXPECTED_ADDRESS=""
IMPL_SALT=""

# Function to display usage
usage() {
    # Example Usage: ./2a-deploy-magicdrop-impl.sh --chain-id 137 --token-standard ERC721 --expected-address 0x0000000000000000000000000000000000000000 --salt 0x0000000000000000000000000000000000000000000000000000000000000000
    echo "Usage: $0 --chain-id <chain id> --version <magic drop impl version> --token-standard <token standard> --expected-address <expected address> --salt <salt>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --token-standard) STANDARD=$2; shift ;;
        --expected-address) IMPL_EXPECTED_ADDRESS=$2; shift ;;
        --salt) IMPL_SALT=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$STANDARD" ] || [ -z "$IMPL_EXPECTED_ADDRESS" ] || [ -z "$IMPL_SALT" ]; then
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
echo "Expected Address:             $IMPL_EXPECTED_ADDRESS"
echo "Salt:                         $IMPL_SALT"
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
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL TOKEN_STANDARD=$STANDARD IMPL_EXPECTED_ADDRESS=$IMPL_EXPECTED_ADDRESS IMPL_SALT=$IMPL_SALT forge script ./DeployMagicDropImplementation.s.sol:DeployMagicDropImplementation \
  --rpc-url $RPC_URL \
  --broadcast \
  --optimizer-runs 777 \
  --via-ir \
  --verify \
  -v

echo ""
echo "============= DEPLOYED MAGICDROP IMPLEMENTATION ============="
echo ""
