#!/usr/bin/env bash

source ./cmds/utils.sh

trap "echo 'Exiting...'; exit 1" SIGINT

deploy_contract() {
    trap "echo 'Exiting...'; exit 1" SIGINT

    load_private_key

    clear 

    title="Deploy a new collection"

        # Pick token standard
    show_title "$title" "> Choose a token standard <"
    token_standard=$(gum choose "ERC721" "ERC1155")
    check_input "$token_standard" "token standard"
    clear
    
    # get chain info
    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
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
        set_rpc_url $chain_id
        clear
    fi
    
    # Pick token standard
    if [ -z "$token_standard" ]; then
        show_title "$title" "> Choose a token standard <"
        token_standard=$(gum choose "ERC721" "ERC1155")
        clear
    fi
    
    # Set token URI suffix with default value of ".json"
    # if [ -z "$TOKEN_URI_SUFFIX" ]; then
    #     show_title "$title" "> Set token URI suffix <"
    #     if gum confirm "Override default token URI suffix? ($DEFAULT_TOKEN_URI_SUFFIX)" --default=false; then
    #         token_uri_suffix=$(gum input --placeholder ".json")
    #     else
    #         token_uri_suffix=$DEFAULT_TOKEN_URI_SUFFIX
    #     fi
    #     clear
    # fi

    # Set max supply (number)
    show_title "$title" "> Set max supply <"
    max_supply=$(get_numeric_input "Enter max supply")
    clear
    
    # Set global wallet limit (number)
    show_title "$title" "> Set global wallet limit <"
    wallet_limit=$(get_numeric_input "Enter global wallet limit")
    clear

    # Check if we need a cosigner
    # show_title "$title" "> Set cosigner <"
    # if gum confirm "Need a cosigner?" --default=false; then
    #     cosigner=$(get_ethereum_address "Cosigner (default: $DEFAULT_COSIGNER)")
    # else
    #     cosigner=$DEFAULT_COSIGNER  
    # fi
    # clear
    
    # # Set timestamp expiry with default value
    # show_title "$title" "> Set timestamp expiry <"
    # if gum confirm "Override default timestamp expiry? ($DEFAULT_TIMESTAMP_EXPIRY seconds)" --default=false; then
    #     timestamp_expiry=$(get_numeric_input "Timestamp expiry (default: $DEFAULT_TIMESTAMP_EXPIRY seconds)")
    # else
    #     timestamp_expiry=$DEFAULT_TIMESTAMP_EXPIRY
    # fi
    # clear
    
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

    load_stages_json "$stages_file"
    if [[ $? -ne 0 ]]; then
        echo "Failed to load stages data"
        exit 1
    fi

    setup_selector="setup(uint256,uint256,address,address,(uint80,uint80,uint32,bytes32,uint24,uint256,uint256)[],address,uint96)"
    output=$(cast send $deployed_contract_address "$setup_selector" $max_supply $wallet_limit $mint_currency $fund_receiver "$STAGES_DATA" $royalty_receiver $royalty_fee --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)
    
    if [ $? -eq 0 ]; then
        tx_hash=$(echo "$output" | jq -r '.transactionHash')
        echo "Transaction successful. Transaction hash: $tx_hash"
    else
        echo "Transaction failed. Error output:"
        echo "$output"
        exit 1
    fi

    echo ""
    echo "Setup complete"
    echo ""
}

set_base_uri() {
    clear

    trap "echo 'Exiting...'; exit 1" SIGINT

    title="Set Base URI"

    base_uri_selector="setBaseURI(string)"

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "Set Base URI")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    clear

    show_title "$title" "> Enter the base URI <"
    base_uri=$(gum input --placeholder "Enter base URI")
    check_input "$base_uri" "base URI"

    set_rpc_url $chain_id

    confirm_set_base_uri

    output=$(gum spin --spinner dot --title "Setting Base URI" -- cast send $contract_address $base_uri_selector $base_uri --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

    if [ $? -eq 0 ]; then
        tx_hash=$(echo "$output" | jq -r '.transactionHash')
        echo "Transaction successful. Transaction hash: $tx_hash"
    else
        echo "Transaction failed. Error output:"
        echo "$output"
    fi

    echo ""
}

set_global_wallet_limit() {
    clear

    trap "echo 'Exiting...'; exit 1" SIGINT

    title="Set Global Wallet Limit"

    global_wallet_limit_selector="setGlobalWalletLimit(uint256)"

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    clear

    show_title "$title" "> Enter the global wallet limit <"
    global_wallet_limit=$(get_numeric_input "Enter global wallet limit")
    check_input "$global_wallet_limit" "global wallet limit"

    set_rpc_url $chain_id

    confirm_set_global_wallet_limit
    output=$(gum spin --spinner dot --title "Setting Global Wallet Limit" -- cast send $contract_address $global_wallet_limit_selector $global_wallet_limit --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

    # TODO(adam) for tomorrow fix bug with setting global wallet limit

    if [ $? -eq 0 ]; then
        tx_hash=$(echo "$output" | jq -r '.transactionHash')
        echo "Transaction successful. Transaction hash: $tx_hash"
    else
        echo "Transaction failed. Error output:"
        echo "$output"
    fi

    echo ""
}

set_max_mintable_supply() {
    echo "Set Max Mintable Supply"
}

set_mintable() {
    echo "Set Mintable"
}

set_stages() {
    echo "Set Stages"
}

set_timestamp_expiry() {
    echo "Set Timestamp Expiry"
}

transfer_ownership() {
    echo "Transfer Ownership"
}

freeze_trading() {
    echo "Freeze/Thaw Trading"
}