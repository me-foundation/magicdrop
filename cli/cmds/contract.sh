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
    output=$(gum spin --spinner dot --title "Setting Up Contract" -- cast send $deployed_contract_address "$setup_selector" $max_supply $wallet_limit $mint_currency $fund_receiver "$STAGES_DATA" $royalty_receiver $royalty_fee --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)
    
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
        output=$(gum spin --spinner dot --title "Setting Max Mintable Supply" -- cast send $contract_address $set_max_mintable_supply_selector $max_mintable_supply --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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
        output=$(gum spin --spinner dot --title "Setting Mintable" -- cast send $contract_address $set_mintable_selector $mintable --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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

    load_private_key

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
    output=$(gum spin --spinner dot --title "Setting Stages" -- cast send $deployed_contract_address "$set_stages_selector" "$STAGES_DATA" --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)
    
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
        output=$(gum spin --spinner dot --title "Setting Cosigner" -- cast send $contract_address $set_cosigner_selector $cosigner --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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
        output=$(gum spin --spinner dot --title "Setting Timestamp Expiry" -- cast send $contract_address $timestamp_expiry_selector $timestamp_expiry --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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
        output=$(gum spin --spinner dot --title "Transferring Ownership" -- cast send $contract_address $complete_ownership_handover_selector $new_owner --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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
    output=$(gum spin --spinner dot --title "Setting Token URI Suffix" -- cast send $contract_address $token_uri_suffix_selector $token_uri_suffix --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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
        output=$(gum spin --spinner dot --title "Setting URI" -- cast send $contract_address $set_uri_selector $uri --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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
        output=$(gum spin --spinner dot --title "Setting Royalties" -- cast send $contract_address $set_royalties_selector $receiver $fee_numerator --chain-id $chain_id --private-key $PRIVATE_KEY --rpc-url "$RPC_URL" --json)

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
