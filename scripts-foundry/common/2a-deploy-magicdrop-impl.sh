#!/usr/bin/env bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

# Exit on error
set -e

# Initialize variables with environment values
CHAIN_ID=${CHAIN_ID:-""}
RPC_URL=""
STANDARD=""
VERSION="" # e.g. 1_0_0, 1_0_1, 1_1_0

# Function to display usage
usage() {
    # Example Usage: ./2a-deploy-magicdrop-impl.sh --chain-id 137 --version 1_0_0 --token-standard ERC721
    echo "Usage: $0 --chain-id <chain id>  --version <magic drop impl version> --token-standard <token standard>"
    exit 1
}

# Function to set RPC URL based on chain ID
set_rpc_url() {
    case $1 in
        1) RPC_URL=$RPC_URL_ETHEREUM ;;
        137) RPC_URL=$RPC_URL_POLYGON ;;
        8453) RPC_URL=$RPC_URL_BASE ;;
        42161) RPC_URL=$RPC_URL_ARBITRUM ;;
        1329) RPC_URL=$RPC_URL_SEI ;;
        33139) RPC_URL=$RPC_URL_APECHAIN ;;
        *) echo "Unsupported chain id"; exit 1 ;;
    esac

    export RPC_URL
}

# Function to set verification api key based on chain ID
set_etherscan_api_key() {
  case $1 in
      1) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_ETHEREUM ;;
      137) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_POLYGON ;;
      8453) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_BASE ;;
      42161) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_ARBITRUM ;;
      1329) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_SEI ;;
      33139) ETHERSCAN_API_KEY=$VERIFICATION_API_KEY_APECHAIN ;;
      *) echo "Unsupported chain id"; exit 1 ;;
  esac

  export ETHERSCAN_API_KEY
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --chain-id) CHAIN_ID=$2; shift ;;
        --version) VERSION=$2; shift ;;
        --token-standard) STANDARD=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$CHAIN_ID" ] || [ -z "$VERSION" ] || [ -z "$STANDARD" ]; then
    usage
fi

# Set the RPC URL based on chain ID
set_rpc_url $CHAIN_ID

# Set the ETHERSCAN API KEY based on chain ID
set_etherscan_api_key $CHAIN_ID

# Construct the contract name
CONTRACT_NAME="${STANDARD}CMInitializableV${VERSION}"

# Create CONTRACT_VERSION by replacing underscores with dots
CONTRACT_VERSION=$(echo $VERSION | tr '_' '.')

# Convert STANDARD to lowercase for the path
STANDARD_LOWERCASE=$(echo $STANDARD | tr '[:upper:]' '[:lower:]')

# Get the bytecode using forge inspect
BYTECODE=$(forge inspect "contracts/nft/$STANDARD_LOWERCASE""m/$CONTRACT_NAME.sol:$CONTRACT_NAME" bytecode --optimizer-runs 777 --via-ir)

# Run the cast create2 command and capture the output
OUTPUT=$(cast create2 --starts-with 0000 --case-sensitive --init-code $BYTECODE)

# Extract the address
EXPECTED_ADDRESS=$(echo "$OUTPUT" | grep "Address:" | awk '{print $2}')

# Extract the salt
SALT=$(echo "$OUTPUT" | grep "Salt:" | awk '{print $2}')
SALT_UINT=$(echo "$OUTPUT" | grep "Salt:" | awk '{print $3}')

# Estimate the deployment cost
EXPECTED_DEPLOY_COST_RAW=$(cast estimate \
    --rpc-url $RPC_URL \
    --chain-id $CHAIN_ID \
    --create \
    $BYTECODE)

# Convert the deployment cost to a human-readable Ether value
EXPECTED_DEPLOY_COST=$(echo "scale=18; $EXPECTED_DEPLOY_COST_RAW / 1000000000000000000" | bc)

echo ""
echo "==================== DEPLOYMENT DETAILS ===================="
echo "Chain ID:                     $CHAIN_ID"
echo "RPC URL:                      $RPC_URL"
echo "Version:                      $CONTRACT_VERSION"
echo "Token Standard:               $STANDARD"
echo "Expected Address:             $EXPECTED_ADDRESS"
echo "Salt:                         $SALT_UINT"
echo "Deployment Cost (native):     $EXPECTED_DEPLOY_COST"
echo "============================================================"
echo ""
read -p "Do you want to proceed? (yes/no) " yn

case $yn in 
  yes ) echo ok, we will proceed;;
  no ) echo exiting...;
    exit;;
  * ) echo invalid response;
    exit 1;;
esac

# Export the variables to the environment
export SALT=$SALT
export EXPECTED_ADDRESS=$EXPECTED_ADDRESS
export TOKEN_STANDARD=$STANDARD
export CONTRACT_VERSION=$CONTRACT_VERSION

echo ""
echo "============= DEPLOYING MAGICDROP IMPLEMENTATION ============="
echo ""

forge script ./DeployMagicDropImplementation.s.sol:DeployMagicDropImplementation \
  --rpc-url $RPC_URL \
  --broadcast \
  --optimizer-runs 777 \
  --via-ir \
  --verify \
  -v

echo ""
echo "============= DEPLOYED MAGICDROP IMPLEMENTATION ============="
echo ""

# Unset the environment variables
unset SALT
unset EXPECTED_ADDRESS
unset TOKEN_STANDARD
unset CONTRACT_VERSION
