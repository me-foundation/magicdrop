#!/usr/bin/env bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

source ./utils

# Exit on error
set -e

# Initialize variables with environment values
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""
STANDARD=""
VERSION="" # e.g. 1_0_0, 1_0_1, 1_1_0

# Function to display usage
usage() {
    # Example Usage: ./2a-deploy-magicdrop-impl.sh --chain-id 137 --version 1_0_0 --token-standard ERC721
    echo "Usage: $0 --chain-id <chain id> --version <magic drop impl version> --token-standard <token standard>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --version) VERSION=$2; shift ;;
        --token-standard) STANDARD=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$VERSION" ] || [ -z "$STANDARD" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

# Construct the contract name
CONTRACT_NAME="${STANDARD}CMInitializableV${VERSION}"

# Create CONTRACT_VERSION by replacing underscores with dots
CONTRACT_VERSION=$(echo $VERSION | tr '_' '.')

# Convert STANDARD to lowercase for the path
STANDARD_LOWERCASE=$(echo $STANDARD | tr '[:upper:]' '[:lower:]')

echo ""
echo "==================== DEPLOYMENT DETAILS ===================="
echo "Chain ID:                     $CHAIN_ID"
echo "RPC URL:                      $RPC_URL"
echo "Version:                      $CONTRACT_VERSION"
echo "Token Standard:               $STANDARD"
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

CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL TOKEN_STANDARD=$STANDARD CONTRACT_VERSION=$CONTRACT_VERSION forge script ./DeployMagicDropImplementation.s.sol:DeployMagicDropImplementation \
  --rpc-url $RPC_URL \
  --broadcast \
  --optimizer-runs 777 \
  --via-ir \
  --verify \
  -v

echo ""
echo "============= DEPLOYED MAGICDROP IMPLEMENTATION ============="
echo ""
