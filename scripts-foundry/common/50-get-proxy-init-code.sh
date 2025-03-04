#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

source ./utils

IMPLEMENTATION=""
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id> --implementation <implementation address>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --implementation) IMPLEMENTATION=$2; shift ;;
        --chain-id) CHAIN_ID=$2; shift ;;
        *) usage ;;
    esac
    shift
done

if [ -z "$IMPLEMENTATION" ] || [ -z "$CHAIN_ID" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

echo "Getting proxy init code for implementation: $IMPLEMENTATION on chain: $CHAIN_ID"

# Get the proxy init code
# NOTE: Remove --broadcast for dry-run
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL IMPLEMENTATION=$IMPLEMENTATION forge script ./ProxyInitCodeHelper.s.sol:ProxyInitCodeHelper \
  --via-ir \
  --optimizer-runs 777 \
  --rpc-url $RPC_URL \
  --broadcast
