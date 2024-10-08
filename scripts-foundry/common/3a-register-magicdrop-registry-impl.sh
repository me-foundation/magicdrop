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
REGISTRY_ADDRESS=""
IMPL_ADDRESS=""
TOKEN_STANDARD=""

# Function to display usage
usage() {
    # Example Usage: ./3a-register-magicdrop-registry-impl.sh --chain-id 137 --registry-address 0x00000001bA03aD5bD3BBB5b5179A5DeBd4dAFed2 --impl-address 0x0000a7f9a573a7289c9506d6a011628acf5a4a45 --token-standard ERC721
    echo "Usage: $0 --chain-id <chain id> --registry-address <registry address> --impl-address <impl address> --token-standard <token standard>"
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

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --registry-address) REGISTRY_ADDRESS=$2; shift ;;
        --impl-address) IMPL_ADDRESS=$2; shift ;;
        --token-standard) TOKEN_STANDARD=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$REGISTRY_ADDRESS" ] || [ -z "$IMPL_ADDRESS" ] || [ -z "$TOKEN_STANDARD" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

echo ""
echo "==================== REGISTRATION DETAILS ===================="
echo "Chain ID:                     $CHAIN_ID"
echo "RPC URL:                      $RPC_URL"
echo "Registry Address:             $REGISTRY_ADDRESS"
echo "Implementation Address:       $IMPL_ADDRESS"
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

export REGISTRY_ADDRESS=$REGISTRY_ADDRESS
export IMPL_ADDRESS=$IMPL_ADDRESS
export TOKEN_STANDARD=$TOKEN_STANDARD

# NOTE: Remove --broadcast for dry-run
forge script ./RegisterMagicDropImpl.s.sol:RegisterMagicDropImpl \
  --rpc-url $RPC_URL \
  --broadcast \
  --via-ir \
  -v

unset REGISTRY_ADDRESS
unset IMPL_ADDRESS
unset TOKEN_STANDARD
