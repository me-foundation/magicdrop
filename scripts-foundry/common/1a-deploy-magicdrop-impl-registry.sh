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
IMPLEMENTATION="0x0000000000000000000000000000000000000000"
REGISTRY_EXPECTED_ADDRESS="0x0000000000000000000000000000000000000000"
ZK_SYNC=false

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id> --salt <salt> --expected-address <expected address> --implementation <implementation address (optional)> --initial-owner <initial owner (optional)> --zk-sync <bool (optional)>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --salt) REGISTRY_SALT=$2; shift ;;
        --expected-address) REGISTRY_EXPECTED_ADDRESS=$2; shift ;;
        --resume) RESUME="--resume" ;;
        --implementation) IMPLEMENTATION=$2; shift ;;
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        --zk-sync) ZK_SYNC=true ;;
    esac
    shift
done

# Check if all parameters are set
if [ $ZK_SYNC ]; then
  if [ -z "$CHAIN_ID" ] || [ -z "$REGISTRY_SALT" ]; then
      usage
  fi
else
  if [ -z "$CHAIN_ID" ] || [ -z "$REGISTRY_SALT" ] || [ -z "$REGISTRY_EXPECTED_ADDRESS"]; then
      usage
  fi
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

echo ""
echo "============= DEPLOYING MAGICDROP IMPL REGISTRY ============="

echo "Chain ID: $CHAIN_ID"
echo "RPC URL: $RPC_URL"
echo "SALT: $REGISTRY_SALT"
if [ $ZK_SYNC ]; then
  echo "ZK SYNC: $ZK_SYNC"
else
  echo "EXPECTED ADDRESS: $REGISTRY_EXPECTED_ADDRESS"
fi
if [ $IMPLEMENTATION != "0x0000000000000000000000000000000000000000" ]; then
  echo "IMPLEMENTATION: $IMPLEMENTATION"
fi
if [ $INITIAL_OWNER != "0x0000000000000000000000000000000000000000" ]; then
  echo "INITIAL OWNER: $INITIAL_OWNER"
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
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL REGISTRY_SALT=$REGISTRY_SALT REGISTRY_EXPECTED_ADDRESS=$REGISTRY_EXPECTED_ADDRESS IMPLEMENTATION=$IMPLEMENTATION INITIAL_OWNER=$INITIAL_OWNER ZK_SYNC=$ZK_SYNC forge script ./DeployMagicDropTokenImplRegistry.s.sol:DeployMagicDropTokenImplRegistry \
  --rpc-url $RPC_URL \
  --broadcast \
  --optimizer-runs 777 \
  --via-ir \
  --verify \
  -v \
  --zksync

# Add for Monad testnet deployment
# --verifier sourcify \
# --verifier-url 'https://sourcify-api-monad.blockvision.org' \

# Add for Abstract
# --zksync \
# --zk-compile 1.5.7 \
# --evm-version cancun \
# --compiler-version 0.8.24 \
# --verifier etherscan \
# --verifier-url 'https://api.abscan.org/api' \
# --skip-simulation
