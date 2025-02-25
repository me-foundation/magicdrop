#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

IMPL_ADDRESS=""

# Function to display usage
usage() {
    echo "Usage: $0 --impl-address <address of implementation>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --impl-address) IMPL_ADDRESS=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$IMPL_ADDRESS" ]; then
    usage
fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different
echo "create2 MagicDropImplRegistry Proxy START"

# constructorArgsNoPrefix=${constructorArgs#0x}
# This is the bytecode that LibClone.deployDeterministicERC1967 will use to deploy the proxy
proxyBytecode="0xfe61002d3d81600a3d39f3363d3d373d3d3d363d73${IMPL_ADDRESS#0x}5af43d82803e903d91602b57fd5bf3"
echo "initCode: $proxyBytecode"

cast create2 --starts-with 0 --case-sensitive --init-code $proxyBytecode
echo "create2 MagicDropImplRegistry Proxy END"
echo "-------------------------------------"
echo ""
