#!/usr/bin/env bash

source ./commands/contract.sh

trap "echo 'Exiting...'; exit 1" SIGINT

contract_management_menu() {
    local option=$(gum choose \
        "Initialize contract" \
        "Set Base URI" \
        "Set Global Wallet Limit" \
        "Set Max Mintable Supply" \
        "Set Mintable" \
        "Set Stages" \
        "Set Timestamp Expiry" \
        "Transfer Ownership" \
        "Freeze/Thaw Trading")

    case $option in
        "Initialize contract")
            setup_contract
            ;;
        "Set Base URI")
            set_base_uri
            ;;
        "Set Global Wallet Limit")
            set_global_wallet_limit
            ;;
        "Set Max Mintable Supply")
            set_max_mintable_supply
            ;;
        "Set Mintable")
            set_mintable
            ;;
        "Set Stages")
            set_stages
            ;;
        "Set Timestamp Expiry")
            set_timestamp_expiry
            ;;
        "Transfer Ownership")
            transfer_ownership
            ;;
        "Freeze/Thaw Trading")
            freeze_trading
            ;;
    esac
}

minting_menu() {
    local option=$(gum choose \
        "Mint Token(s)" \
        "Owner Mint ERC721M" \
        "Owner Mint ERC1155M")

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
    esac
}

token_operations_menu() {
    local option=$(gum choose \
        "Send ERC721 Batch")

    case $option in
        "Send ERC721 Batch")
            npx hardhat send721Batch
            ;;
    esac
}