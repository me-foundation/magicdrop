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

#!/bin/bash

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
        PRIVATE_KEY=$(jq -r '.private_key // empty' defaults.json)
        DEFAULT_ROYALTY_RECEIVER=$(jq -r '.default_royalty_receiver // empty' defaults.json)
        DEFAULT_ROYALTY_FEE=$(jq -r '.default_royalty_fee // empty' defaults.json)
    else 
        echo "No defaults.json found."
        exit 1
    fi
}

load_private_key() {
    if [[ -f "defaults.json" ]]; then
        PRIVATE_KEY=$(jq -r '.private_key // empty' defaults.json)
        SIGNER=$(jq -r '.signer // empty' defaults.json)
    fi

    if [[ -z "$PRIVATE_KEY" || -z "$SIGNER" ]]; then
        PRIVATE_KEY=$(gum input --placeholder "Enter private key")

        SIGNER=$(cast wallet address --private-key $PRIVATE_KEY)
        if [[ -z "$SIGNER" ]]; then
            echo "Invalid private key. Please enter a valid private key."
            exit 1
        fi

        jq --arg value "$PRIVATE_KEY" '.private_key = $value' defaults.json > tmp.json && mv tmp.json defaults.json
        jq --arg value "$SIGNER" '.signer = $value' defaults.json > tmp.json && mv tmp.json defaults.json
        echo ""
        echo "Private key and signer saved to defaults.json"
        echo ""
    fi
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
    while true; do
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
            return
        else
            echo "Invalid input. Please enter a valid Ethereum address."
        fi
    done
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
    echo "Impl ID:                      $(gum style --foreground 212 "$impl_id")"
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
    echo "Token URI Suffix:             $(gum style --foreground 212 "$token_uri_suffix")"
    echo "Max Supply:                   $(gum style --foreground 212 "$max_supply")"
    echo "Global Wallet Limit:          $(gum style --foreground 212 "$wallet_limit")"
    echo "Cosigner:                     $(gum style --foreground 212 "$(format_address "$cosigner")")"
    echo "Timestamp Expiry:             $(gum style --foreground 212 "$timestamp_expiry")"
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


#==============================================================#
#                          MAIN MENU                           #
#==============================================================#
main_menu() {
    trap "echo 'Exiting...'; exit 1" SIGINT

    show_main_title

    option=$(gum choose \
    "Deploy Contracts" \
    "Manage Contracts" \
    "Mint Tokens" \
    "Token Operations" \
    "Quit"
     )

    case $option in
        "Deploy Contracts")
            # deploy_contract
            ;;
        "Manage Contracts")
            # setup_contract
            ;;
        "Quit")
            echo "Exiting..."
            exit 0
            ;;
    esac
}

deploy_contract() {
    trap "echo 'Exiting...'; exit 1" SIGINT

    load_private_key

    clear 

    title="Deploy a new collection"
    
    # Pick chain
    show_title "$title" "> Choose a chain to deploy on <"
    chain=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | cut -d':' -f2 | gum choose)
    chain_id=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | grep "$chain" | cut -d':' -f1)
    clear

    # Pick token standard
    show_title "$title" "> Choose a token standard <"
    token_standard=$(gum choose "ERC721" "ERC1155")
    check_input "$token_standard" "token standard"
    clear

    # get name
    show_title "$title" "> Set name <"
    name=$(gum input --placeholder "Enter name")
    check_input "$name" "name"
    clear

    # get symbol
    show_title "$title" "> Set symbol <"
    symbol=$(gum input --placeholder "Enter symbol")
    check_input "$symbol" "symbol"
    clear

    # ask if they want to override the signer as the initial owner
    show_title "$title" "> Set initial owner <"
    if gum confirm "Override initial owner? ($(format_address $SIGNER))" --default=false; then
        initial_owner=$(get_ethereum_address "Initial owner")
    else
        initial_owner=$SIGNER
    fi
    clear

    # get impl id
    show_title "$title" "> Set implementation ID <"
    impl_id=$(get_numeric_input "Enter implementation ID")
    clear

    confirm_deployment

    # run deploy-factory-clone.sh
    OUTPUT=$(PRIVATE_KEY=$PRIVATE_KEY ./../scripts-foundry/common/deploy-factory-clone.sh \
        --chain-id $chain_id --name "$name" --symbol "$symbol" \
        --token-standard "$token_standard" --initial-owner "$initial_owner" \
        --impl-id "$impl_id" --skip-confirmation true)

    echo $OUTPUT

    DEPLOYED_CONTRACT_ADDRESS=$(echo "$OUTPUT" | grep -oE '0x[a-fA-F0-9]{40}')

    if [ $? -ne 0 ]; then
        echo "Deployment failed"
        exit 1
    fi
    
    # ask if they would like to setup the contract now
    if gum confirm "Would you like to setup the contract?"; then
        setup_contract "$DEPLOYED_CONTRACT_ADDRESS" "$chain_id" "$token_standard" "$initial_owner"
    fi
}

setup_contract() {
    trap "echo 'Exiting...'; exit 1" SIGINT

    local deployed_contract_address="$1"
    local chain_id="$2"
    local token_standard="$3"
    local initial_owner="$4"

    load_private_key

    clear 

    title="Setup an existing collection"

    # Pick chain
    if [ -z "$chain_id" ]; then
        show_title "$title" "> Choose a chain to deploy on <"
        chain=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | cut -d':' -f2 | gum choose)
        # Extract the chain ID based on the selected chain name
        chain_id=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | grep "$chain" | cut -d':' -f1)
        clear
    fi
    
    # Pick token standard
    if [ -z "$token_standard" ]; then
        show_title "$title" "> Choose a token standard <"
        token_standard=$(gum choose "ERC721" "ERC1155")
        clear
    fi
    
    # Set token URI suffix with default value of ".json"
    if [ -z "$TOKEN_URI_SUFFIX" ]; then
        show_title "$title" "> Set token URI suffix <"
        if gum confirm "Override default token URI suffix? ($DEFAULT_TOKEN_URI_SUFFIX)" --default=false; then
            token_uri_suffix=$(gum input --placeholder ".json")
        else
            token_uri_suffix=$DEFAULT_TOKEN_URI_SUFFIX
        fi
        clear
    fi

    # Set max supply (number)
    show_title "$title" "> Set max supply <"
    max_supply=$(get_numeric_input "Enter max supply")
    clear
    
    # Set global wallet limit (number)
    show_title "$title" "> Set global wallet limit <"
    wallet_limit=$(get_numeric_input "Enter global wallet limit")
    clear

    # Check if we need a cosigner
    show_title "$title" "> Set cosigner <"
    if gum confirm "Need a cosigner?" --default=false; then
        cosigner=$(get_ethereum_address "Cosigner (default: $DEFAULT_COSIGNER)")
    else
        cosigner=$DEFAULT_COSIGNER  
    fi
    clear
    
    # Set timestamp expiry with default value
    show_title "$title" "> Set timestamp expiry <"
    if gum confirm "Override default timestamp expiry? ($DEFAULT_TIMESTAMP_EXPIRY seconds)" --default=false; then
        timestamp_expiry=$(get_numeric_input "Timestamp expiry (default: $DEFAULT_TIMESTAMP_EXPIRY seconds)")
    else
        timestamp_expiry=$DEFAULT_TIMESTAMP_EXPIRY
    fi
    clear
    
    # Set mint currency (default to native gas token)
    show_title "$title" "> Set mint currency <"
    if gum confirm "Using a custom mint currency?" --default=false; then
        mint_currency=$(get_ethereum_address "Mint currency (default: Native Gas Token)")
    else
        mint_currency=$DEFAULT_MINT_CURRENCY
    fi
    clear

    # Check if royalties are needed
    show_title "$title" "> Do you want to set royalties? <"
    if gum confirm "Use royalties?" --default=false; then
        # Set royalty receiver
        show_title "$title" "> Set royalty receiver <"
        royalty_receiver=$(get_ethereum_address "Enter royalty receiver address")
        royalty_receiver=${royalty_receiver:-"N/A"}
        clear

        # Set royalty fee numerator
        show_title "$title" "> Set royalty fee numerator <"
        royalty_fee=$(get_numeric_input "Enter royalty fee numerator (e.g., 500 for 5%)")
        royalty_fee=${royalty_fee:-"N/A"}
        clear
    else 
        royalty_receiver=$DEFAULT_ROYALTY_RECEIVER
        royalty_fee=$DEFAULT_ROYALTY_FEE
    fi

    clear

    # Set stages by reading from a JSON file, default is stages.json
    show_title "$title" "> Set stages file <"
    stages_file=$(get_file "Enter stages JSON file")
    clear

    # Set fund receiver
    show_title "$title" "> Set fund receiver <"
    if gum confirm "Override fund receiver? (default: $(format_address $SIGNER))" --default=false; then
        fund_receiver=$(get_ethereum_address "Fund receiver (eg: 0x000...000)")
    else
        fund_receiver=$SIGNER
    fi
    clear

    # Get deployed contract address
    if [ -z "$deployed_contract_address" ]; then
        show_title "$title" "> Enter deployed contract address <"
        deployed_contract_address=$(gum input --placeholder "Enter a deployed contract address")
        check_input "$deployed_contract_address" "deployed contract address"
    fi

    confirm_setup

    # convert $chain to lowercase for hardhat
    hardhat_network=$(echo "$chain" | tr '[:upper:]' '[:lower:]')
    PRIVATE_KEY=$PRIVATE_KEY npx hardhat setStages --network $hardhat_network --contract $deployed_contract_address --stages "$stages_file"

    if [ $? -ne 0 ]; then
        echo "Setup failed"
        exit 1
    fi

    echo ""
    echo "Setup complete"
}

contract_management_menu() {
    local option=$(gum choose \
        "Set Base URI" \
        "Set Global Wallet Limit" \
        "Set Max Mintable Supply" \
        "Set Mintable State" \
        "Set Stages" \
        "Set 1155 Stages" \
        "Set Timestamp Expiry Seconds" \
        "Transfer Ownership" \
        "Freeze Trading" \
        "Thaw Trading" \
        "Clean Whitelist" \
        "Back to main menu")

    case $option in
        "Set Base URI")
            npx hardhat setBaseURI
            ;;
        "Set Global Wallet Limit")
            npx hardhat setGlobalWalletLimit
            ;;
        "Set Max Mintable Supply")
            npx hardhat setMaxMintableSupply
            ;;
        "Set Mintable State")
            npx hardhat setMintable
            ;;
        "Set Stages")
            npx hardhat setStages
            ;;
        "Set 1155 Stages")
            npx hardhat set1155Stages
            ;;
        "Set Timestamp Expiry Seconds")
            npx hardhat setTimestampExpirySeconds
            ;;
        "Transfer Ownership")
            npx hardhat transferOwnership
            ;;
        "Freeze Trading")
            npx hardhat freezeTrading
            ;;
        "Thaw Trading")
            npx hardhat thawTrading
            ;;
        "Clean Whitelist")
            npx hardhat cleanWhitelist
            ;;
        "Back to main menu")
            main_menu
            ;;
    esac
}

minting_menu() {
    local option=$(gum choose \
        "Mint Token(s)" \
        "Owner Mint ERC721M" \
        "Owner Mint ERC1155M" \
        "Back to main menu")

    case $option in
        "Mint Token(s)")
            npx hardhat mint
            ;;
        "Owner Mint ERC721M")
            npx hardhat ownerMint
            ;;
        "Owner Mint ERC1155M")
            npx hardhat ownerMint1155
            ;;
        "Back to main menu")
            main_menu
            ;;
    esac
}

token_operations_menu() {
    local option=$(gum choose \
        "Send ERC721 Batch" \
        "Back to main menu")

    case $option in
        "Send ERC721 Batch")
            npx hardhat send721Batch
            ;;
        "Back to main menu")
            main_menu
            ;;
    esac
}

load_defaults

# Run the menu only if the configuration is complete
if [[ "$CONFIG_COMPLETE" == true ]]; then
    main_menu
else
    echo "Configuration is incomplete. Please ensure all values are set in defaults.json."
fi