#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi


INITIAL_OWNER=""

# Function to display usage
usage() {
    echo "Usage: $0 --initial-owner <initial owner address>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --initial-owner) INITIAL_OWNER=$2; shift ;;
        *) usage ;;
    esac
    shift
done

if [ -z "$INITIAL_OWNER" ]; then
    usage
fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropImplRegistry START"
registryByteCode="$(forge inspect contracts/registry/MagicDropTokenImplRegistry.sol:MagicDropTokenImplRegistry bytecode --optimizer-runs 777 --via-ir)"

# Encode the constructor arguments
constructorArgs=$(cast abi-encode "constructor(address)" $INITIAL_OWNER)
constructorArgsNoPrefix=${constructorArgs#0x}

# Concatenate the bytecode and constructor arguments
registryInitCode=$(cast concat-hex $registryByteCode $constructorArgsNoPrefix)

echo "registryInitCode: $registryInitCode"

cast create2 --starts-with 00000000 --case-sensitive --init-code $registryInitCode
echo "create2 MagicDropImplRegistry END"
echo "-------------------------------------"
echo ""
