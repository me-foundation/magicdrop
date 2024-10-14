#!/usr/bin/env bash

trap "echo 'Exiting...'; exit 1" SIGINT

SUPPORTED_CHAINS=(
    "33139:ApeChain"
    "42161:Arbitrum"
    "8453:Base"
    "1:Ethereum"
    "137:Polygon"
    "1329:Sei"
)

MAGIC_DROP_KEYSTORE="MAGIC_DROP_KEYSTORE"
export ETH_KEYSTORE_ACCOUNT=$MAGIC_DROP_KEYSTORE

#==============================================================#
#                      HELPER FUNCTIONS                        #
#==============================================================#
load_defaults() {
    CONFIG_COMPLETE=true

    if [[ -f "defaults.json" ]]; then
        # Read values from defaults.json using jq
        DEFAULT_COSIGNER=$(jq -r '.default_cosigner // empty' defaults.json)
        DEFAULT_TIMESTAMP_EXPIRY=$(jq -r '.default_timestamp_expiry // empty' defaults.json)
        DEFAULT_MINT_CURRENCY=$(jq -r '.default_mint_currency // empty' defaults.json)
        DEFAULT_TOKEN_URI_SUFFIX=$(jq -r '.default_token_uri_suffix // empty' defaults.json)
        DEFAULT_ROYALTY_RECEIVER=$(jq -r '.default_royalty_receiver // empty' defaults.json)
        DEFAULT_ROYALTY_FEE=$(jq -r '.default_royalty_fee // empty' defaults.json)
        DEFAULT_MERKLE_ROOT=$(jq -r '.default_merkle_root // empty' defaults.json)
    else 
        echo "No defaults.json found."
        exit 1
    fi

    source .env
}

get_password_if_set() {
    if [[ -n "$KEYSTORE_PASSWORD" ]]; then
        echo "--password $KEYSTORE_PASSWORD"
    else
        echo ""
    fi
}

load_private_key() {
    keystore_file="$HOME/.foundry/keystores/$MAGIC_DROP_KEYSTORE"

    # Check if the keystore file exists
    if [[ -f "$keystore_file" ]]; then
        return 0
    fi

    echo "============================================================"
    echo ""
    echo "MagicDrop CLI requires a private key to send transactions."
    echo "This key controls all funds in the account, so it must be protected carefully."
    echo ""
    echo "MagicDrop CLI will create an encrypted keystore for your private key."
    echo "You will be prompted to enter your private key and a password to encrypt it."
    echo "Learn more: https://book.getfoundry.sh/reference/cast/cast-wallet-import"
    echo ""
    echo "This password will be required to send transactions from your account."
    echo ""
    echo "============================================================"
    echo ""
    cast wallet import --interactive $MAGIC_DROP_KEYSTORE

    echo ""
    echo "Keystore created successfully"
    echo "You can store your password in .env to avoid entering it every time"
    echo "echo \"KEYSTORE_PASSWORD=<your_password>\" >> .env"
    echo ""

    if [[ $? -ne 0 ]]; then
        echo "Failed to create keystore"
        exit 1
    fi
}

load_signer() {
    password=$(get_password_if_set)
    export SIGNER=$(cast wallet address $password)
}

check_input() {
    local input_value="$1"
    local input_name="$2"
    if [[ -z "$input_value" ]]; then
        echo "No input received for $input_name. Exiting..."
        exit 1
    fi
}

is_number() {
    local input="$1"
    [[ "$input" =~ ^[0-9]+$ ]]
}

get_numeric_input() {
    local prompt="$1"
    local input
    while true; do
        input=$(gum input --placeholder "$prompt (or 'exit' to quit)")
        
        if [[ -z "$input" ]]; then
            echo "Exiting program..."
            kill $$
        elif [[ "$input" == "exit" || "$input" == "quit" ]]; then
            echo "Exiting program..."
            kill $$
        fi

        # If the input is numeric, return it
        if is_number "$input"; then
            echo "$input"
            return
        fi
    done
}

is_valid_ethereum_address() {
    local address="$1"
    [[ "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]
}

get_ethereum_address() {
    local prompt="$1"
    local address

    address=$(gum input --placeholder "$prompt (or 'exit' to quit)")
    if [[ -z "$address" ]]; then
        echo "Exiting program..."
        kill $$
    elif [[ "$address" == "exit" || "$address" == "quit" ]]; then
        echo "Exiting program..."
        kill $$
    fi

    if is_valid_ethereum_address "$address"; then
        echo "$address"
    else
        echo "Invalid input. Exiting..."
        exit 1
    fi
}

file_exists() {
    local file="$1"
    [[ -f "$file" ]]
}

get_file() {
    local prompt="$1"
    local file
    while true; do
        file=$(gum file --height 10)

        if file_exists "$file"; then
            echo "$file"
            return
        else
            echo "File not found. Please enter a valid file path."
        fi
    done
}

format_address() {
    local address=$1
    local prefix=${address:0:6}
    local suffix=${address: -4}
    echo "${prefix}...${suffix}"
}

function display_info {
    local output=""

    for arg in "$@"; do
        key=$(echo "$arg" | cut -d':' -f1)
        value=$(echo "$arg" | cut -d':' -f2)
        output+="$(gum style --foreground="#ffcc00" "$key"): $(gum style --foreground="#00ffcc" "$value")\n"
    done

    echo -e "$output" | gum format
}

confirm_deployment() {
    echo ""
    echo "==================== DEPLOYMENT DETAILS ===================="
    echo "Name:                         $(gum style --foreground 212 "$name")"
    echo "Symbol:                       $(gum style --foreground 212 "$symbol")"
    echo "Token Standard:               $(gum style --foreground 212 "$token_standard")"
    echo "Initial Owner:                $(gum style --foreground 212 "$(format_address "$initial_owner")")"
    if [[ "$impl_id" -eq 0 ]]; then
        echo "Impl ID:                      $(gum style --foreground 212 "DEFAULT")"
    else
        echo "Impl ID:                      $(gum style --foreground 212 "$impl_id")"
    fi
    echo "Chain ID:                     $(gum style --foreground 212 "$chain_id")"
    echo "============================================================"
    echo ""

    if ! gum confirm "Do you want to proceed?"; then
        echo "Exiting..."
        exit 1
    fi
}

confirm_setup() {
    echo ""
    echo "==================== CONTRACT DETAILS ===================="
    echo "Chain:                        $(gum style --foreground 212 "$chain")"
    echo "Token Standard:               $(gum style --foreground 212 "$token_standard")"
    echo "Contract Address:             $(gum style --foreground 212 "$(format_address "$deployed_contract_address")")"
    echo "======================= SETUP INFO ======================="
    echo "Max Supply:                   $(gum style --foreground 212 "$max_supply")"
    echo "Global Wallet Limit:          $(gum style --foreground 212 "$wallet_limit")"
    echo "Mint Currency:                $(gum style --foreground 212 "$(format_address "$mint_currency")")"
    echo "Royalty Receiver:             $(gum style --foreground 212 "$(format_address "$royalty_receiver")")"
    echo "Royalty Fee:                  $(gum style --foreground 212 "$royalty_fee")"
    echo "Stages File:                  $(gum style --foreground 212 "$stages_file")"
    echo "Fund Receiver:                $(gum style --foreground 212 "$(format_address "$fund_receiver")")"
    echo "=========================================================="
    echo ""

    if ! gum confirm "Do you want to proceed?"; then
        echo "Exiting..."
        exit 1
    fi
}

confirm_set_base_uri() {
    echo ""
    echo "==================== BASE URI ===================="
    echo "Contract Address:             $(gum style --foreground 212 "$(format_address "$contract_address")")"
    echo "Chain ID:                     $(gum style --foreground 212 "$chain_id")"
    echo "Base URI:                     $(gum style --foreground 212 "$base_uri")"
    echo "==================================================="
    echo ""
    
    if ! gum confirm "Do you want to proceed?"; then
        echo "Exiting..."
        exit 1
    fi
}

confirm_set_global_wallet_limit() {
    echo ""
    echo "==================== GLOBAL WALLET LIMIT ===================="
    echo "Contract Address:             $(gum style --foreground 212 "$(format_address "$contract_address")")"
    echo "Chain ID:                     $(gum style --foreground 212 "$chain_id")"
    echo "Global Wallet Limit:          $(gum style --foreground 212 "$global_wallet_limit")"
    echo "==========================================================="
    echo ""

    if ! gum confirm "Do you want to proceed?"; then
        echo "Exiting..."
        exit 1
    fi
}

confirm_set_token_uri_suffix() {
    echo ""
    echo "==================== TOKEN URI SUFFIX ===================="
    echo "Contract Address:             $(gum style --foreground 212 "$(format_address "$contract_address")")"
    echo "Chain ID:                     $(gum style --foreground 212 "$chain_id")"
    echo "Token URI Suffix:             $(gum style --foreground 212 "$token_uri_suffix")"
    echo "==========================================================="
    echo ""
    
    if ! gum confirm "Do you want to proceed?"; then
        echo "Exiting..."
        exit 1
    fi
}

show_main_title() {
    gum style \
	--foreground 212 --border-foreground 212 --border double \
	--align center --width 40 --margin "1 0" --padding "1" \
	'MagicDrop CLI' '' 'Create and manage NFT collections'
}

show_title() {
    local title="$1"
    local subtitle="$2"
    gum style \
    --foreground 212 --border-foreground 212 --border double \
    --align center --width 40 --margin "1 0" --padding "1" \
    "$title" \
    "$subtitle"
}

select_chain() {
    local chain=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | cut -d':' -f2 | gum choose)
    local chain_id=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | grep "$chain" | cut -d':' -f1)
    echo "$chain_id:$chain"
}

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

generateMerkleRoot() {
    result=$(npx ts-node ./../scripts/utils/generateMerkleRoot.ts $1 false)
    echo "$result" | sed -n 's/^Merkle Root: *//p'
}

load_stages_json() {
    local stages_file="$1"
    if [[ ! -f "$stages_file" ]]; then
        echo "Error: Stages file not found: $stages_file"
        return 1
    fi

    # Extract whitelistPath
    local whitelistPaths
    whitelistPaths=$(jq -r '.[].whitelistPath' "$stages_file")

    merkle_roots=()
    for whitelistPath in $whitelistPaths; do
        if [[ -z "$whitelistPath" || "$whitelistPath" == "null" ]]; then
            merkle_roots+=("$DEFAULT_MERKLE_ROOT")
        else
            result=$(generateMerkleRoot "$whitelistPath")
            if [[ $? -ne 0 ]]; then
                echo "Error: Failed to generate merkle root"
                return 1
            fi
            merkle_roots+=("$result")
        fi
    done
    json_array=$(printf '%s\n' "${merkle_roots[@]}" | jq -R . | jq -s .)

    # Map the stages data from the JSON file, and replace the merkle root with the generated one
    stages_data=$(jq -c --argjson merkle_roots "$json_array" '
        to_entries | map(
            [
                (.value.price | tonumber * 1e18 | floor),
                (.value.mintFee | tonumber * 1e18 | floor),
                (.value.walletLimit | tonumber),
                ($merkle_roots[.key] // empty),
                (.value.maxStageSupply // 0 | tonumber),
                (.value.startDate | fromdateiso8601 | tonumber),
                (.value.endDate | fromdateiso8601 | tonumber)
            ]
        )
    ' "$stages_file")


    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to parse stages JSON"
        return 1
    fi

    stages_data=$(echo "$stages_data" | sed 's/"//g') # remove any quotes

    # Replace inner square brackets with parentheses, but keep the outer brackets
    # this is necessary to format the MintStages struct correctly for `cast send`
    RESULT=$(echo "$stages_data" | awk '{
        gsub(/\[/, "(");
        gsub(/\]/, ")");
        if (NR == 1) sub(/^\(/, "[");
        if (NR == FNR) last_line = $0;
    } END {
        sub(/\)$/, "]", last_line);
        print last_line;
    }')

    export STAGES_DATA="$RESULT"
}

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

save_deployment_data() {
    chain_id=$1
    deployment_data=$2

    # Get the current timestamp
    timestamp=$(date +%s)
    # Create the directory if it doesn't exist
    deployment_dir="./deployments/$chain_id"
    mkdir -p "$deployment_dir"

    file_name="$NAME-$STANDARD-$timestamp.json"
    echo "$deployment_data" > "$deployment_dir/$file_name"
    echo "Deployment details saved to $deployment_dir/$file_name"
}
