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
INITIAL_OWNER="0x0000000000000000000000000000000000000000"
REGISTRY="0x0000000000000000000000000000000000000000"
IMPLEMENTATION="0x0000000000000000000000000000000000000000"

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id> --salt <salt> --expected-address <expected address> --initial-owner <initial owner (optional)> --registry-address <registry address (optional)> --implementation <implementation address (optional)>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --salt) FACTORY_SALT=$2; shift ;;
        --expected-address) FACTORY_EXPECTED_ADDRESS=$2; shift ;;
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        --registry) REGISTRY=$2; shift ;;
        --implementation) IMPLEMENTATION=$2; shift ;;
        --resume) RESUME="--resume" ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$FACTORY_SALT" ] || [ -z "$FACTORY_EXPECTED_ADDRESS" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

echo ""
echo "============= DEPLOYING MAGICDROP CLONE FACTORY ============="

echo "Chain ID: $CHAIN_ID"
echo "RPC URL: $RPC_URL"
echo "SALT: $FACTORY_SALT"
echo "EXPECTED ADDRESS: $FACTORY_EXPECTED_ADDRESS"
if [ $INITIAL_OWNER != "0x0000000000000000000000000000000000000000" ]; then
  echo "INITIAL OWNER: $INITIAL_OWNER"
fi
if [ $REGISTRY != "0x0000000000000000000000000000000000000000" ]; then
  echo "REGISTRY: $REGISTRY"
fi
if [ $IMPLEMENTATION != "0x0000000000000000000000000000000000000000" ]; then
  echo "IMPLEMENTATION: $IMPLEMENTATION"
fi

read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# NOTE: Remove --broadcast for dry-run
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL FACTORY_SALT=$FACTORY_SALT FACTORY_EXPECTED_ADDRESS=$FACTORY_EXPECTED_ADDRESS INITIAL_OWNER=$INITIAL_OWNER REGISTRY=$REGISTRY IMPLEMENTATION=$IMPLEMENTATION forge script ./DeployMagicDropCloneFactory.s.sol:DeployMagicDropCloneFactory \
  --rpc-url $RPC_URL \
  --broadcast \
  --via-ir \
  --verify
