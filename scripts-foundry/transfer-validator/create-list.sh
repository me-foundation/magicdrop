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
LIST_NAME=$3

RPC_URL=""


usage() {
    echo "Usage: $0 --chain-id <chain id> --transfer-validator <transfer validator address> --list-name <list name>"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --transfer-validator) TRANSFER_VALIDATOR=$2; shift ;;
        --list-name) LIST_NAME=$2; shift ;;
        *) usage ;;
    esac
    shift
done

if [ -z "$CHAIN_ID" ] || [ -z "$TRANSFER_VALIDATOR" ] || [ -z "$LIST_NAME" ]; then
    usage
fi

set_rpc_url $CHAIN_ID

echo "Creating list $LIST_NAME on $CHAIN_ID with transfer validator $TRANSFER_VALIDATOR"

cast send $TRANSFER_VALIDATOR "createList(string)" $LIST_NAME \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
