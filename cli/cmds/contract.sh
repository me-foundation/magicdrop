#!/usr/bin/env bash

source ./cmds/utils.sh

trap "echo 'Exiting...'; exit 1" SIGINT

deploy_contract() {
    trap "echo 'Exiting...'; exit 1" SIGINT
    clear 

    title="Deploy a new collection"

        # Pick token standard
    show_title "$title" "> Choose a token standard <"
    token_standard=$(gum choose "ERC721" "ERC1155")
    check_input "$token_standard" "token standard"
    clear

    case $token_standard in
        ERC721) standard_id=0 ;;
        ERC1155) standard_id=1 ;;
        *) echo "Unsupported token standard"; exit 1 ;;
    esac
    
    # get chain info
    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    set_rpc_url $chain_id
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

    load_signer

    # ask if they want to override the signer as the initial owner
    show_title "$title" "> Set initial owner <"
    if gum confirm "Override initial owner? ($(format_address $SIGNER))" --default=false; then
        initial_owner=$(get_ethereum_address "Initial owner")
    else
        initial_owner=$SIGNER
    fi
    clear

    show_title "$title" "> Set implementation ID <"
    if gum confirm "Override default implementation?" --default=false; then
        impl_id=$(get_numeric_input "Enter implementation ID")
        clear
    else
        # when using impl_id=0, the contract will fallback to the default implementation
        impl_id=0
    fi


    confirm_deployment

    create_contract_selector="createContract(string,string,uint8,address,uint32)"
    factory_address="0x000073735DD587b1e5d3E84025A1145e110D4684"

    password=$(get_password_if_set)

    echo "Deploying contract... this may take a minute."
    echo ""
    output=$(gum spin --spinner dot --title "Deploying Contract" -- \
    cast send \
    --rpc-url "$RPC_URL" \
    --chain-id $chain_id \
    $factory_address \
    "$create_contract_selector" \
    "$name" \
    "$symbol" \
    "$standard_id" \
    "$initial_owner" \
    $impl_id \
    $password \
    --json)

    if [ $? -eq 0 ]; then
        tx_hash=$(echo "$output" | jq -r '.transactionHash')
        echo "Transaction successful. Transaction hash: $tx_hash"
        save_deployment_data $chain_id $output

        sig_event=$(cast sig-event "NewContractInitialized(address,address,uint32,uint8,string,string)")
        event_data=$(get_contract_address "$output" "$sig_event")
        chunks=($(echo "$event_data" | fold -w64))
        contract_address=$(decode_address "${chunks[0]}")
        echo "Deployed Contract Address: $contract_address"
        echo ""

        # ask if they would like to setup the contract now
        if gum confirm "Would you like to setup the contract?"; then
            setup_contract "$contract_address" "$chain_id" "$token_standard" "$initial_owner"
        fi
    else
        echo "Transaction failed. Error output:"
        echo "$output"
    fi
}

setup_contract() {
    trap "echo 'Exiting...'; exit 1" SIGINT

    local deployed_contract_address="$1"
    local chain_id="$2"
    local token_standard="$3"
    local initial_owner="$4"

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

    # Set max supply (number)
    show_title "$title" "> Set max supply <"
    max_supply=$(get_numeric_input "Enter max supply")
    clear
    
    # Set global wallet limit (number)
    show_title "$title" "> Set global wallet limit <"
    wallet_limit=$(get_numeric_input "Enter global wallet limit")
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

    # todo(adam): see if we can remove this
    load_signer

    # Set fund receiver
    show_title "$title" "> Set fund receiver <"
    if gum confirm "Override fund receiver? (default: $(format_address $SIGNER))" --default=false; then
        fund_receiver=$(get_ethereum_address "Fund receiver (eg: 0x000...000)")
    else
        fund_receiver=$SIGNER
    fi
    clear

    # Get contract address
    if [ -z "$contract_address" ]; then
        show_title "$title" "> Enter contract address <"
        contract_address=$(gum input --placeholder "Enter contract address")
        check_input "$contract_address" "contract address"
    fi

    confirm_setup

    load_stages_json "$stages_file"
    if [[ $? -ne 0 ]]; then
        echo "Failed to load stages data"
        exit 1
    fi

    password=$(get_password_if_set)
    
    setup_selector="setup(uint256,uint256,address,address,(uint80,uint80,uint32,bytes32,uint24,uint256,uint256)[],address,uint96)"
    output=$(gum spin --spinner dot --title "Setting Up Contract" -- \
        cast send $contract_address \
        "$setup_selector" \
        $max_supply \
        $wallet_limit \
        $mint_currency \
        $fund_receiver \
        "$STAGES_DATA" \
        $royalty_receiver \
        $royalty_fee \
        $password \
        --chain-id $chain_id \
        --rpc-url "$RPC_URL" \
        --json)
    
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

    password=$(get_password_if_set)
    output=$(gum spin --spinner dot --title "Setting Base URI" -- \
        cast send $contract_address \
        $base_uri_selector \
        $base_uri \
        $password \
        --chain-id $chain_id \
        --rpc-url "$RPC_URL" \
        --json)

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
    password=$(get_password_if_set)
    output=$(gum spin --spinner dot --title "Setting Global Wallet Limit" -- \
        cast send $contract_address \
        $global_wallet_limit_selector \
        $global_wallet_limit \
        $password \
        --chain-id $chain_id \
        --rpc-url "$RPC_URL" \
        --json)

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
    trap "echo 'Exiting...'; exit 1" SIGINT

    title="Set Max Mintable Supply"

    show_title "$title" "> Choose a chain to deploy on <"
    chain=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | cut -d':' -f2 | gum choose)
    # Extract the chain ID based on the selected chain name
    chain_id=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | grep "$chain" | cut -d':' -f1)
    set_rpc_url $chain_id
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Enter the max mintable supply <"
    max_mintable_supply=$(get_numeric_input "Enter max mintable supply")
    check_input "$max_mintable_supply" "max mintable supply"

    echo ""
    echo "You are about to set the max mintable supply of $(format_address $contract_address) to $max_mintable_supply"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        set_max_mintable_supply_selector="setMaxMintableSupply(uint256)"
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Setting Max Mintable Supply" -- \
            cast send $contract_address \
            $set_max_mintable_supply_selector \
            $max_mintable_supply \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
        else
            echo "Transaction failed. Error output:"
            echo "$output"
            exit 1
        fi
    else
        echo "Set max mintable supply cancelled."
    fi

    echo ""
}

set_mintable() {
    trap "echo 'Exiting...'; exit 1" SIGINT

    title="Set Mintable"

    show_title "$title" "> Choose a chain to deploy on <"
    chain=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | cut -d':' -f2 | gum choose)
    # Extract the chain ID based on the selected chain name
    chain_id=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | grep "$chain" | cut -d':' -f1)
    set_rpc_url $chain_id
    clear

    show_title "$title" "> Choose a token standard <"
    token_standard=$(gum choose "ERC721" "ERC1155")
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Set mintable <"
    if gum confirm "Set mintable?" --default=false; then
        mintable=true
    else
        mintable=false
    fi
    clear

    echo ""
    echo "You are about to set the mintable status of $(format_address $contract_address) to $mintable"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        set_mintable_selector="setMintable(bool)"
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Setting Mintable" -- \
            cast send $contract_address \
            $set_mintable_selector \
            $mintable \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Set mintable cancelled."
    fi

    echo ""
}

set_stages() {
    trap "echo 'Exiting...'; exit 1" SIGINT
    clear 

    title="Set Stages"

    show_title "$title" "> Choose a chain to deploy on <"
    chain=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | cut -d':' -f2 | gum choose)
    # Extract the chain ID based on the selected chain name
    chain_id=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | grep "$chain" | cut -d':' -f1)
    set_rpc_url $chain_id
    clear
    
    show_title "$title" "> Choose a token standard <"
    token_standard=$(gum choose "ERC721" "ERC1155")
    clear

    # Set stages by reading from a JSON file, default is stages.json
    show_title "$title" "> Set stages file <"
    stages_file=$(get_file "Enter stages JSON file")
    clear

    show_title "$title" "> Enter contract address <"
    deployed_contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$deployed_contract_address" "contract address"
    clear

    load_stages_json "$stages_file"
    if [[ $? -ne 0 ]]; then
        echo "Failed to load stages data"
        exit 1
    fi

    set_stages_selector="setStages((uint80,uint80,uint32,bytes32,uint24,uint256,uint256)[])"
    password=$(get_password_if_set)
    output=$(gum spin --spinner dot --title "Setting Stages" -- \
        cast send $deployed_contract_address \
        "$set_stages_selector" \
        "$STAGES_DATA" \
        --chain-id $chain_id \
        --rpc-url "$RPC_URL" \
        --json)
    
    if [ $? -eq 0 ]; then
        tx_hash=$(echo "$output" | jq -r '.transactionHash')
        echo "Transaction successful. Transaction hash: $tx_hash"
    else
        echo "Transaction failed. Error output:"
        echo "$output"
        exit 1
    fi

    echo ""
    echo "Stages setup complete"
    echo ""
}

set_cosigner() {
    clear

    trap "echo 'Exiting...'; exit 1" SIGINT

    title="Set Cosigner"

    show_title "$title" "> Choose a chain to deploy on <"
    chain=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | cut -d':' -f2 | gum choose)
    # Extract the chain ID based on the selected chain name
    chain_id=$(printf "%s\n" "${SUPPORTED_CHAINS[@]}" | grep "$chain" | cut -d':' -f1)
    set_rpc_url $chain_id
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Enter cosigner address <"
    cosigner=$(get_ethereum_address "Enter cosigner address")
    check_input "$cosigner" "cosigner address"
    clear

    echo ""
    echo "You are about to set the cosigner of $(format_address $contract_address) to $(format_address $cosigner)"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        set_cosigner_selector="setCosigner(address)"
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Setting Cosigner" -- \
            cast send $contract_address \
            $set_cosigner_selector \
            $cosigner \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
        else
            echo "Transaction failed. Error output:"
            echo "$output"
            exit 1
        fi
    else
        echo "Set cosigner cancelled."
    fi

    echo ""
}

set_timestamp_expiry() {
    clear

    trap "echo 'Exiting...'; exit 1" SIGINT

    title="Set Timestamp Expiry"

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    set_rpc_url $chain_id
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Enter the timestamp expiry <"
    timestamp_expiry=$(get_numeric_input "Enter timestamp expiry in seconds")
    check_input "$timestamp_expiry" "timestamp expiry"

    echo ""
    echo "You are about to set the timestamp expiry of $(format_address $contract_address) to $timestamp_expiry seconds."
    echo ""

    if gum confirm "Do you want to proceed?"; then
        timestamp_expiry_selector="setTimestampExpirySeconds(uint256)"
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Setting Timestamp Expiry" -- \
            cast send $contract_address \
            $timestamp_expiry_selector \
            $timestamp_expiry \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
        else
            echo "Transaction failed. Error output:"
            echo "$output"
            exit 1
        fi
    else
        echo "Timestamp expiry cancelled."
    fi

    echo ""
}

transfer_ownership() {
    clear
    trap "echo 'Exiting...'; exit 1" SIGINT
    title="Complete Ownership Handover"

    echo ""
    echo "Notice: In order to transfer ownership, the next owner must call 'requestOwnershipTransfer(address)' on the contract."
    echo "This request will expire in 48 hours. Once expired, the request can be made again by the new owner."
    echo "After the request is made, the current owner can proceed with this action."
    echo ""

    if ! gum confirm "Do you want to proceed?"; then
        echo "Exiting..."
        exit 1
    fi

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    set_rpc_url $chain_id
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Enter new owner address <"
    new_owner=$(get_ethereum_address "Enter new owner address")
    check_input "$new_owner" "new owner address"
    clear
    
    echo ""
    echo "You are about to transfer ownership of $(format_address $contract_address) to $(format_address $new_owner)"
    echo "This action cannot be undone."
    echo ""

    if gum confirm "Do you want to proceed?"; then
        complete_ownership_handover_selector="completeOwnershipHandover(address)"
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Transferring Ownership" -- \
            cast send $contract_address \
            $complete_ownership_handover_selector \
            $new_owner \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Transfer ownership cancelled."
    fi

    echo ""
}

set_token_uri_suffix() {
    clear
    trap "echo 'Exiting...'; exit 1" SIGINT
    title="Set Token URI Suffix"

    show_title "$title" "> Set token URI suffix <"
    if gum confirm "Override default token URI suffix? ($DEFAULT_TOKEN_URI_SUFFIX)" --default=false; then
        token_uri_suffix=$(gum input --placeholder ".json")
    else
        token_uri_suffix=$DEFAULT_TOKEN_URI_SUFFIX
    fi
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    clear

    set_rpc_url $chain_id

    confirm_set_token_uri_suffix

    token_uri_suffix_selector="setTokenURISuffix(string)"
    password=$(get_password_if_set)
    output=$(gum spin --spinner dot --title "Setting Token URI Suffix" -- \
        cast send $contract_address \
        $token_uri_suffix_selector \
        $token_uri_suffix \
        $password \
        --chain-id $chain_id \
        --rpc-url "$RPC_URL" \
        --json)

    if [ $? -eq 0 ]; then
        tx_hash=$(echo "$output" | jq -r '.transactionHash')
        echo "Transaction successful. Transaction hash: $tx_hash"
    else
        echo "Transaction failed. Error output:"
        echo "$output"
    fi

    echo ""
}

set_uri() {
    clear
    trap "echo 'Exiting...'; exit 1" SIGINT
    title="Set URI (ERC1155 Only)"

    show_title "$title" "> Enter ERC1155 contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Enter new URI <"
    uri=$(gum input --placeholder "Enter new URI")
    check_input "$uri" "URI"
    clear

    echo ""
    echo "You are about to set the URI of $(format_address $contract_address) to $uri"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        set_uri_selector="setURI(string)"
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Setting URI" -- \
            cast send $contract_address \
            $set_uri_selector \
            $uri \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Set URI cancelled."
    fi

    echo ""
}

set_royalties() {
    clear
    trap "echo 'Exiting...'; exit 1" SIGINT
    title="Set Royalties"

    echo ""
    echo "Notice: This only works for contracts that implement the ERC2981 standard."
    echo "Newer versions of ERC721M and ERC1155M support this out of the box."
    echo ""

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    set_rpc_url $chain_id
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Enter receiver address <"
    receiver=$(get_ethereum_address "Enter receiver address")
    check_input "$receiver" "receiver address"
    clear
    
    show_title "$title" "> Enter fee numerator <"
    echo "Notice: The fee numerator is a number from 0 to 10000."
    echo "It shows the royalty fee as a percentage."
    echo "For example, 1000 means 10%, 100 means 1%, and 0 means 0%."
    echo ""

    fee_numerator=$(get_numeric_input "Enter fee numerator")
    check_input "$fee_numerator" "fee numerator"
    clear

    echo ""
    percentage=$(echo "scale=2; $fee_numerator / 100" | bc)
    echo "You are about to set the royalties of $(format_address $contract_address) to $(format_address $receiver) with a fee numerator of $fee_numerator ($percentage%)"
    echo ""
    
    if gum confirm "Do you want to proceed?"; then
        set_royalties_selector="setDefaultRoyalty(address,uint96)"
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Setting Royalties" -- \
            cast send $contract_address \
            $set_royalties_selector \
            $receiver \
            $fee_numerator \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Set royalties cancelled."
    fi

    echo ""
}

owner_mint() {
    clear
    trap "echo 'Exiting...'; exit 1" SIGINT
    title="Mint Tokens"

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    chain=$(echo "$chain_info" | cut -d':' -f2)
    set_rpc_url $chain_id
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    token_standard=$(get_token_standard "$contract_address")
    show_title "$title" "> Choose a token standard <"
    token_standard=$(gum choose "ERC721" "ERC1155")
    clear

    show_title "$title" "> Enter recipient address <"
    recipient=$(get_ethereum_address "Enter recipient address")
    check_input "$recipient" "recipient address"
    clear
    
    show_title "$title" "> Enter quantity <"
    quantity=$(get_numeric_input "Enter quantity")
    check_input "$quantity" "quantity"
    clear

    token_id=""
    mint_selector="ownerMint(uint32,address)" # ERC721 mint(to, quantity)
    mint_args="$quantity $recipient"
    if [ "$token_standard" == "ERC1155" ]; then
        token_id=$(get_numeric_input "Enter token ID")
        check_input "$token_id" "token ID"
        clear
        mint_selector="ownerMint(address,uint256,uint32)" # ERC1155 mint(to, tokenId, quantity)
        mint_args="$recipient $token_id $quantity"
    fi

    echo ""
    echo "You are about to mint $quantity token(s) of token ID #$token_id to $(format_address $recipient)"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        password=$(get_password_if_set)
        output=$(gum spin --spinner dot --title "Minting" -- \
            cast send $contract_address \
            "$mint_selector" \
            $mint_args \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
            echo ""
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Mint cancelled."
    fi
}

send_erc721_batch() {
    echo "Not implemented, please use the hardhat script instead."
}

manage_authorized_minters() {
    clear
    trap "echo 'Exiting...'; exit 1" SIGINT
    title="Manage Authorized Minters"

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Choose an action <"
    action=$(gum choose "Add Authorized Minter" "Remove Authorized Minter")
    clear

    show_title "$title" "> Enter minter address <"
    minter=$(get_ethereum_address "Enter minter address")
    check_input "$minter" "minter address"
    clear

    if [ "$action" == "Add Authorized Minter" ]; then
        add_authorized_minter $contract_address $minter $chain_id
    else
        remove_authorized_minter $contract_address $minter $chain_id
    fi
}

add_authorized_minter() {
    contract_address=$1
    minter=$2
    chain_id=$3

    set_rpc_url $chain_id
    password=$(get_password_if_set)
    add_authorized_minter_selector="addAuthorizedMinter(address)"

    echo ""
    echo "You are about to add $(format_address $minter) as an authorized minter of $(format_address $contract_address)"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        output=$(gum spin --spinner dot --title "Adding Authorized Minter" -- \
            cast send $contract_address \
            "$add_authorized_minter_selector" \
            $minter \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
            --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
            echo ""
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Add authorized minter cancelled."
    fi
}

remove_authorized_minter() {
    contract_address=$1
    minter=$2
    chain_id=$3

    set_rpc_url $chain_id
    password=$(get_password_if_set)
    remove_authorized_minter_selector="removeAuthorizedMinter(address)"

    echo ""
    echo "You are about to remove $(format_address $minter) as an authorized minter of $(format_address $contract_address)"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        output=$(gum spin --spinner dot --title "Removing Authorized Minter" -- \
            cast send $contract_address \
            "$remove_authorized_minter_selector" \
            $minter \
            $password \
            --chain-id $chain_id \
            --rpc-url "$RPC_URL" \
        --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
            echo ""
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Remove authorized minter cancelled."
    fi
}

set_cosigner() {
    trap "echo 'Exiting...'; exit 1" SIGINT
    title="Set Cosigner"

    show_title "$title" "> Choose a chain <"
    chain_info=$(select_chain "$title")
    chain_id=$(echo "$chain_info" | cut -d':' -f1)
    clear

    show_title "$title" "> Enter contract address <"
    contract_address=$(get_ethereum_address "Enter contract address")
    check_input "$contract_address" "contract address"
    clear

    show_title "$title" "> Enter cosigner address <"
    cosigner=$(get_ethereum_address "Enter cosigner address")
    check_input "$cosigner" "cosigner address"
    clear

    set_rpc_url $chain_id
    password=$(get_password_if_set)
    set_cosigner_selector="setCosigner(address)"

    echo ""
    echo "You are about to set the cosigner of $(format_address $contract_address) to $(format_address $cosigner)"
    echo ""

    if gum confirm "Do you want to proceed?"; then
        output=$(gum spin --spinner dot --title "Setting Cosigner" -- \
        cast send $contract_address \
        "$set_cosigner_selector" \
        $cosigner \
        $password \
        --chain-id $chain_id \
        --rpc-url "$RPC_URL" \
        --json)

        if [ $? -eq 0 ]; then
            tx_hash=$(echo "$output" | jq -r '.transactionHash')
            echo "Transaction successful. Transaction hash: $tx_hash"
            echo ""
        else
            echo "Transaction failed. Error output:"
            echo "$output"
        fi
    else
        echo "Set cosigner cancelled."
    fi
}

