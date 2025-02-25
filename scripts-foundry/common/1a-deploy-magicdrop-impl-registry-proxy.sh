#!/usr/bin/env bash

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
IMPL_ADDRESS=""

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id> -- impl-address <impl address> --salt <salt> --expected-address <expected address> --initial-owner <initial owner>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --impl-address) IMPL_ADDRESS=$2; shift ;;
        --salt) REGISTRY_SALT=$2; shift ;;
        --expected-address) REGISTRY_EXPECTED_ADDRESS=$2; shift ;;
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        --resume) RESUME="--resume" ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$IMPL_ADDRESS" ] || [ -z "$REGISTRY_SALT" ] || [ -z "$REGISTRY_EXPECTED_ADDRESS" ] || [ -z "$INITIAL_OWNER" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

echo ""
echo "============= DEPLOYING MAGICDROP IMPL REGISTRY ============="

echo "Chain ID: $CHAIN_ID"
echo "RPC URL: $RPC_URL"
echo "IMPL ADDRESS: $IMPL_ADDRESS"
echo "SALT: $REGISTRY_SALT"
echo "EXPECTED ADDRESS: $REGISTRY_EXPECTED_ADDRESS"
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# NOTE: Remove --broadcast and --verify for dry-run
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL IMPL_ADDRESS=$IMPL_ADDRESS REGISTRY_SALT=$REGISTRY_SALT REGISTRY_EXPECTED_ADDRESS=$REGISTRY_EXPECTED_ADDRESS INITIAL_OWNER=$INITIAL_OWNER forge script ./DeployMagicDropTokenImplRegistryProxy.s.sol:DeployMagicDropTokenImplRegistryProxy \
  --rpc-url $RPC_URL \
  --optimizer-runs 777 \
  --via-ir \
  -v
