#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

source ./utils

# Initialize variables with environment values
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""
RESUME=""

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --resume) RESUME="--resume" ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

echo ""
echo "============= DEPLOYING MAGICDROP IMPL REGISTRY ============="

echo "Chain ID: $CHAIN_ID"
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# NOTE: Remove --broadcast and --verify for dry-run
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL forge script ./DeployMagicDropTokenImplRegistry.s.sol:DeployMagicDropTokenImplRegistry \
  --rpc-url $RPC_URL \
  --optimizer-runs 777 \
  --via-ir \
  --broadcast \
  --verify \
  -v