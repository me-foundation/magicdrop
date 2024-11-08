#!/usr/bin/env bash

if [ -f ../common/.env ]
then
  export $(grep -v '^#' ../common/.env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

set -e

source ../common/utils

CHAIN_ID=$1
TRANSFER_VALIDATOR=$2
LIST_ID=$3
ACCOUNTS=$4

RPC_URL=""


usage() {
    echo "Usage: $0 --chain-id <chain id> --transfer-validator <transfer validator address> --list-id <list id> --accounts '[<account1>,<account2>,...]'"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --transfer-validator) TRANSFER_VALIDATOR=$2; shift ;;
        --list-id) LIST_ID=$2; shift ;;
        --accounts) ACCOUNTS=$2; shift ;;
        *) usage ;;
    esac
    shift
done

if [ -z "$CHAIN_ID" ] || [ -z "$TRANSFER_VALIDATOR" ] || [ -z "$LIST_ID" ] || [ -z "$ACCOUNTS" ]; then
    usage
fi


set_rpc_url $CHAIN_ID

echo "Adding accounts to authorizers on $CHAIN_ID with transfer validator $TRANSFER_VALIDATOR"

cast send $TRANSFER_VALIDATOR "addAccountsToAuthorizers(uint120,address[])" $LIST_ID $ACCOUNTS \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
