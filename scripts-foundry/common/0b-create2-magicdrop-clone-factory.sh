#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

# REGISTRY_ADDRESS=""
# INITIAL_OWNER=""

# Function to display usage
usage() {
    # echo "Usage: $0 --initial-owner <initial owner address> --registry-address <registry address>"
    echo "Usage: $0"

    exit 1
}

# Process arguments
# while [[ "$#" -gt 0 ]]; do
#     case $1 in
#         --initial-owner) INITIAL_OWNER=$2; shift ;;
#         --registry-address) REGISTRY_ADDRESS=$2; shift ;;
#         *) usage ;;
#     esac
#     shift
# done

# if [ -z "$INITIAL_OWNER" ] || [ -z "$REGISTRY_ADDRESS" ]; then
#     usage
# fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropCloneFactory START"
factoryCode="$(forge inspect contracts/factory/MagicDropCloneFactory.sol:MagicDropCloneFactory bytecode --optimizer-runs 777 --via-ir)"

# Encode the constructor arguments
# constructorArgs=$(cast abi-encode "constructor(address,address)" $INITIAL_OWNER $REGISTRY_ADDRESS)
# constructorArgsNoPrefix=${constructorArgs#0x}
factoryInitCode=$(cast concat-hex $factoryCode)

cast create2 --starts-with 00000000 --case-sensitive --init-code $factoryInitCode
echo "create2 MagicDropCloneFactory END"
echo "-------------------------------------"
echo ""
