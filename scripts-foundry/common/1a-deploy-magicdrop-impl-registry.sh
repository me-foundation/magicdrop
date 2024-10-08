#!/usr/bin/env bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

# Initialize variables with environment values
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""
RESUME=""

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id>"
    exit 1
}

# Function to set RPC URL based on chain ID
set_rpc_url() {
    case $1 in
        1) RPC_URL=$RPC_URL_ETHEREUM ;;
        137) RPC_URL=$RPC_URL_POLYGON ;;
        8453) RPC_URL=$RPC_URL_BASE ;;
        42161) RPC_URL=$RPC_URL_ARBITRUM ;;
        1329) RPC_URL=$RPC_URL_SEI ;;
        33139) RPC_URL=$RPC_URL_APECHAIN ;;
        *) echo "Unsupported chain id"; exit 1 ;;
    esac

    export RPC_URL
}

# Function to set verification api key based on chain ID
set_etherscan_api_key() {
  case $1 in
      1) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_ETHEREUM ;;
      137) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_POLYGON ;;
      8453) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_BASE ;;
      42161) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_ARBITRUM ;;
      1329) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_SEI ;;
      33139) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_APECHAIN ;;
      *) echo "Unsupported chain id"; exit 1 ;;
  esac

  export ETHERSCAN_API_KEY
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
echo "RPC URL: $RPC_URL"
echo "SALT: $SALT"
echo "EXPECTED ADDRESS: $EXPECTED_ADDRESS"
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# NOTE: Remove --broadcast for dry-run
forge script ./DeployMagicDropTokenImplRegistry.s.sol:DeployMagicDropTokenImplRegistry \
  --rpc-url $RPC_URL \
  --broadcast \
  --optimizer-runs 777 \
  --via-ir \
  --verify $RESUME \
  -v
