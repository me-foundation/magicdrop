#!/usr/bin/env bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

source ./utils.sh

# Initialize variables with environment values
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""
RESUME=""

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id> --salt <salt> --expected-address <expected address> --initial-owner <initial owner> --registry-address <registry address>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --salt) FACTORY_SALT=$2; shift ;;
        --expected-address) FACTORY_EXPECTED_ADDRESS=$2; shift ;;
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        --registry-address) REGISTRY_ADDRESS=$2; shift ;;
        --resume) RESUME="--resume" ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$FACTORY_SALT" ] || [ -z "$FACTORY_EXPECTED_ADDRESS" ] || [ -z "$INITIAL_OWNER" ] || [ -z "$REGISTRY_ADDRESS" ]; then
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
echo "INITIAL OWNER: $INITIAL_OWNER"
echo "REGISTRY ADDRESS: $REGISTRY_ADDRESS"
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# NOTE: Remove --broadcast for dry-run
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL FACTORY_SALT=$FACTORY_SALT FACTORY_EXPECTED_ADDRESS=$FACTORY_EXPECTED_ADDRESS INITIAL_OWNER=$INITIAL_OWNER REGISTRY_ADDRESS=$REGISTRY_ADDRESS forge script ./DeployMagicDropCloneFactory.s.sol:DeployMagicDropCloneFactory \
  --rpc-url $RPC_URL \
  --broadcast \
  --via-ir # \
  # --verify $RESUME \
  # -v
