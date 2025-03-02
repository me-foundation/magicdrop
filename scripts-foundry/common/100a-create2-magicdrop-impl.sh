#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

NAME=""
SYMBOL=""
TOKEN_URI_SUFFIX=""
MAX_MINTABLE_SUPPLY="1000"
GLOBAL_WALLET_LIMIT="0"
COSIGNER="0x0000000000000000000000000000000000000000"
TIMESTAMP_EXPIRY_SECONDS="60"
MINT_CURRENCY="0x0000000000000000000000000000000000000000"
FUND_RECEIVER=""
MINT_FEE="0"

# Function to display usage
usage() {
    echo "Usage: $0 --impl <path to implementation> --name <name> --symbol <symbol> --fund-receiver <fund receiver address> --mint-fee <mint fee>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --impl) IMPL_PATH=$2; shift ;;
        --name) NAME=$2; shift ;;
        --symbol) SYMBOL=$2; shift ;;
        --fund-receiver) FUND_RECEIVER=$2; shift ;;
        --mint-fee) MINT_FEE=$2; shift ;;
        *) usage ;;
    esac
    shift
done

echo "IMPL_PATH: $IMPL_PATH"
echo "NAME: $NAME"
echo "SYMBOL: $SYMBOL"
echo "FUND_RECEIVER: $FUND_RECEIVER"
echo "MINT_FEE: $MINT_FEE"

# Check if all parameters are set
if [ -z "$IMPL_PATH" ] || [ -z "$NAME" ] || [ -z "$SYMBOL" ] || [ -z "$FUND_RECEIVER" ] || [ -z "$MINT_FEE" ]; then
    usage
fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropImpl START"

implByteCode="$(forge inspect contracts/nft/erc721m/ERC721CM.sol:ERC721CM bytecode --optimizer-runs 777 --via-ir)"
constructorArgs=$(cast abi-encode "constructor(string,string,string,uint256,uint256,address,uint256,address,address,uint256)" "$NAME" "$SYMBOL" "$TOKEN_URI_SUFFIX" "$MAX_MINTABLE_SUPPLY" "$GLOBAL_WALLET_LIMIT" "$COSIGNER" "$TIMESTAMP_EXPIRY_SECONDS" "$MINT_CURRENCY" "$FUND_RECEIVER" "$MINT_FEE")
constructorArgsNoPrefix=${constructorArgs#0x}
implInitCode=$(cast concat-hex $implByteCode $constructorArgsNoPrefix)

cast create2 --starts-with 88888888 --case-sensitive --init-code $implInitCode
echo "create2 MagicDropImpl END"
echo "-------------------------------------"
echo ""
