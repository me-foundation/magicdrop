#!/usr/bin/env bash

# Exit on error
set -e

# Initialize variables with environment values
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""
NAME=""
SYMBOL=""
STANDARD=""
INITIAL_OWNER=""
IMPL_ID=""
SKIP_CONFIRMATION=${SKIP_CONFIRMATION:-false}

# Magicdrop Factory Clone
NEW_CONTRACT_EVENT_SIG_EVENT=$(cast sig-event "NewContractInitialized(address,address,uint32,uint8,string,string)")
CREATE_CONTRACT_SELECTOR="createContract(string,string,uint8,address,uint32)"
FACTORY_ADDRESS="0x000005305814D026e49Bd08f444359FC27BB113e"

# Function to display usage
usage() {
    echo "Usage: $0 --chain-id <chain id> --name <name> --symbol <symbol> --token-standard <token standard> --initial-owner <initial owner> --impl-id <impl id>"
    exit 1
}

# Function to set RPC URL based on chain ID. These are free RPC, public RPCs.
set_rpc_url() {
    case $1 in
        1) RPC_URL="https://cloudflare-eth.com" ;; # Ethereum
        137) RPC_URL="https://polygon-rpc.com" ;; # Polygon
        8453) RPC_URL="https://mainnet.base.org" ;; # Base
        42161) RPC_URL="https://arb1.arbitrum.io/rpc" ;; # Arbitrum
        1329) RPC_URL="https://evm-rpc.sei-apis.com" ;; # Sei
        33139) RPC_URL="https://curtis.rpc.caldera.xyz/http" ;; # ApeChain
        *) echo "Unsupported chain id"; exit 1 ;;
    esac

    export RPC_URL
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --name) NAME=$2; shift ;;
        --symbol) SYMBOL=$2; shift ;;
        --token-standard) STANDARD=$2; shift ;;
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        --impl-id) IMPL_ID=$2; shift ;;
        --skip-confirmation) SKIP_CONFIRMATION=true; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$NAME" ] || [ -z "$SYMBOL" ] || \
   [ -z "$STANDARD" ] || [ -z "$INITIAL_OWNER" ] || [ -z "$IMPL_ID" ]; then
    usage
fi

# Set the RPC URL based on chain ID
if [ -z "$RPC_URL" ]; then
    set_rpc_url $CHAIN_ID
fi

# Set the token standard to the corresponding value
case $STANDARD in
    ERC721) STANDARD_ID=0 ;;
    ERC1155) STANDARD_ID=1 ;;
    *) echo "Unsupported token standard"; exit 1 ;;
esac

format_address() {
    local address=$1
    local prefix=${address:0:6}
    local suffix=${address: -4}
    echo "${prefix}...${suffix}"
}

confirm_deployment() {
    echo ""
    echo "==================== DEPLOYMENT DETAILS ===================="
    echo "Name:                         $(gum style --foreground 212 "$NAME")"
    echo "Symbol:                       $(gum style --foreground 212 "$SYMBOL")"
    echo "Token Standard:               $(gum style --foreground 212 "$STANDARD")"
    echo "Initial Owner:                $(gum style --foreground 212 "$(format_address "$INITIAL_OWNER")")"
    echo "Impl ID:                      $(gum style --foreground 212 "$IMPL_ID")"
    echo "Chain ID:                     $(gum style --foreground 212 "$CHAIN_ID")"
    echo "============================================================"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        echo "Ok, we will proceed"
    else
        echo "Exiting..."
        exit 1
    fi
}

if [ "$SKIP_CONFIRMATION" = false ]; then
    confirm_deployment
fi

# Deploy the factory clone
DEPLOYMENT_DATA=$(cast send \
    --rpc-url "$RPC_URL" \
    --chain-id $CHAIN_ID \
    --private-key $PRIVATE_KEY \
    $FACTORY_ADDRESS \
    $CREATE_CONTRACT_SELECTOR \
    "$NAME" \
    "$SYMBOL" \
    "$STANDARD_ID" \
    "$INITIAL_OWNER" \
    $IMPL_ID \
    --json)

if [ $? -ne 0 ]; then
    echo "Failed to deploy factory clone"
    exit 1
else 
    echo "Factory clone deployed successfully"
fi

save_deployment_data() {
    # Get the current timestamp
    local timestamp=$(date +%s)
    # Create the directory if it doesn't exist
    local deployment_dir="./deployments/$CHAIN_ID"
    mkdir -p "$deployment_dir"
    # Construct the file name
    local file_name="$NAME-$STANDARD-$timestamp.json"
    # Save the deployment_data to the file
    echo "$DEPLOYMENT_DATA" > "$deployment_dir/$file_name"
    echo "Deployment details saved to $deployment_dir/$file_name"
}

save_deployment_data

extract_log_data() {
    local log="$1"
    echo $(echo "$log" | jq -r '.data' | sed 's/^0x//')
}

get_contract_address() {
    local deployment_data="$1"
    local event_sig="$2"
    
    for log in $(echo "$deployment_data" | jq -c '.logs[]'); do
        local topic0=$(echo "$log" | jq -r '.topics[0]')
        if [ "$topic0" == "$event_sig" ]; then
            echo $(extract_log_data "$log")
            return
        fi
    done
}

decode_address() {
  chunk=$1
  # Take the last 40 characters (20 bytes for an address)
  echo "0x${chunk:24}"
}

NEW_CONTRACT_EVENT_DATA=$(get_contract_address "$DEPLOYMENT_DATA" "$NEW_CONTRACT_EVENT_SIG_EVENT")
CHUNKS=($(echo "$NEW_CONTRACT_EVENT_DATA" | fold -w64))
DEPLOYED_CONTRACT_ADDRESS=$(decode_address "${CHUNKS[0]}")

echo "Deployed Contract Address: $DEPLOYED_CONTRACT_ADDRESS"
