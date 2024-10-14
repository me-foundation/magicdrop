#!/usr/bin/env bash

source ./cmds/menu.sh
source ./cmds/contract.sh
source ./cmds/utils.sh

main_menu() {
    trap "echo 'Exiting...'; exit 1" SIGINT

    show_main_title

    load_private_key

    option=$(gum choose \
    "Deploy Contracts" \
    "Manage Contracts" \
    "Mint Tokens" \
    "Token Operations" \
    "Quit")

    case $option in
        "Deploy Contracts")
            deploy_contract
            go_to_main_menu_or_exit
            ;;
        "Manage Contracts")
            contract_management_menu
            go_to_main_menu_or_exit
            ;;
        "Mint Tokens")
            minting_menu
            go_to_main_menu_or_exit
            ;;
        "Token Operations")
            token_operations_menu
            go_to_main_menu_or_exit
            ;;
        "Quit")
            echo "Exiting..."
            exit 0
            ;;
    esac
}

go_to_main_menu_or_exit() {
    if gum confirm "Go to main menu?"; then
        main_menu
    else
        echo "Exiting..."
        exit 0
    fi
}
