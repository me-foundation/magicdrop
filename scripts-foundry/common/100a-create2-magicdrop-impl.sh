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
INITIAL_OWNER=""

# Function to display usage
usage() {
    echo "Usage: $0 --impl <path to implementation> --name <name> --symbol <symbol> --fund-receiver <fund receiver address> --uri <token uri suffix> --maxMintableSupply <max mintable supply> --globalWalletLimit <global wallet limit> --cosigner <cosigner address> --timestamp-expiry <timestamp expiry seconds> --mint-currency <mint currency address> --initial-owner <initial owner address>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --impl) IMPL_PATH=$2; shift ;;
        --name) NAME=$2; shift ;;
        --symbol) SYMBOL=$2; shift ;;
        --uri) TOKEN_URI_SUFFIX=$2; shift ;;
        --maxMintableSupply) MAX_MINTABLE_SUPPLY=$2; shift ;;
        --globalWalletLimit) GLOBAL_WALLET_LIMIT=$2; shift ;;
        --cosigner) COSIGNER=$2; shift ;;
        --timestamp-expiry) TIMESTAMP_EXPIRY_SECONDS=$2; shift ;;
        --mint-currency) MINT_CURRENCY=$2; shift ;;
        --fund-receiver) FUND_RECEIVER=$2; shift ;;
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        *) usage ;;
    esac
    shift
done

echo "IMPL_PATH: $IMPL_PATH"
echo "NAME: $NAME"
echo "SYMBOL: $SYMBOL"
echo "TOKEN_URI_SUFFIX: $TOKEN_URI_SUFFIX"
echo "MAX_MINTABLE_SUPPLY: $MAX_MINTABLE_SUPPLY"
echo "GLOBAL_WALLET_LIMIT: $GLOBAL_WALLET_LIMIT"
echo "COSIGNER: $COSIGNER"
echo "TIMESTAMP_EXPIRY_SECONDS: $TIMESTAMP_EXPIRY_SECONDS"
echo "MINT_CURRENCY: $MINT_CURRENCY"
echo "FUND_RECEIVER: $FUND_RECEIVER"
echo "INITIAL_OWNER: $INITIAL_OWNER"

# Check if all parameters are set
if [ -z "$IMPL_PATH" ] || [ -z "$NAME" ] || [ -z "$SYMBOL" ] || [ -z "$TOKEN_URI_SUFFIX" ] || [ -z "$MAX_MINTABLE_SUPPLY" ] || [ -z "$GLOBAL_WALLET_LIMIT" ] || [ -z "$COSIGNER" ] || [ -z "$TIMESTAMP_EXPIRY_SECONDS" ] || [ -z "$MINT_CURRENCY" ] || [ -z "$FUND_RECEIVER" ] || [ -z "$INITIAL_OWNER" ]; then
    usage
fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropImpl START"

implByteCode="$(forge inspect contracts/nft/erc721m/ERC721CM.sol:ERC721CM bytecode --optimizer-runs 777 --via-ir)"
constructorArgs=$(cast abi-encode "constructor(string,string,string,uint256,uint256,address,uint256,address,address,address)" "$NAME" "$SYMBOL" "$TOKEN_URI_SUFFIX" "$MAX_MINTABLE_SUPPLY" "$GLOBAL_WALLET_LIMIT" "$COSIGNER" "$TIMESTAMP_EXPIRY_SECONDS" "$MINT_CURRENCY" "$FUND_RECEIVER" "$INITIAL_OWNER")
constructorArgsNoPrefix=${constructorArgs#0x}
implInitCode=$(cast concat-hex $implByteCode $constructorArgsNoPrefix)

echo $implByteCode
echo $constructorArgs

cast create2 --starts-with 88888888 --case-sensitive --init-code $implInitCode
echo "create2 MagicDropImpl END"
echo "-------------------------------------"
echo ""