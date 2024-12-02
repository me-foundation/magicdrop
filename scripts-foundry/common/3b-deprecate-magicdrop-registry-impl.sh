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
REGISTRY_ADDRESS=""
TOKEN_STANDARD=""
IMPL_ID=""

# Function to display usage
usage() {
    # Example Usage: ./3b-deprecate-magicdrop-registry-impl.sh --chain-id 137 --registry-address 0x00000001bA03aD5bD3BBB5b5179A5DeBd4dAFed2 --impl-id 1 --token-standard ERC721
    echo "Usage: $0 --chain-id <chain id> --registry-address <registry address> --impl-id <impl id> --token-standard <token standard>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --registry-address) REGISTRY_ADDRESS=$2; shift ;;
        --impl-id) IMPL_ID=$2; shift ;;
        --token-standard) TOKEN_STANDARD=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$REGISTRY_ADDRESS" ] || [ -z "$IMPL_ID" ] || [ -z "$TOKEN_STANDARD" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

echo ""
echo "==================== DEPRECATION DETAILS ===================="
echo "Chain ID:                     $CHAIN_ID"
echo "RPC URL:                      $RPC_URL"
echo "Registry Address:             $REGISTRY_ADDRESS"
echo "Implementation ID:            $IMPL_ID"
echo "Token Standard:               $TOKEN_STANDARD"
echo "============================================================="
echo ""
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# NOTE: Remove --broadcast for dry-run
CHAIN_ID=$CHAIN_ID RPC_URL=$RPC_URL REGISTRY_ADDRESS=$REGISTRY_ADDRESS IMPL_ID=$IMPL_ID TOKEN_STANDARD=$TOKEN_STANDARD forge script ./DeprecateMagicDropImpl.s.sol:DeprecateMagicDropImpl \
  --broadcast \
  --via-ir \
  -v
