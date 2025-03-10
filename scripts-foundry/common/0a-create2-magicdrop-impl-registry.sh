#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

PROXY_INIT_CODE=""

# Function to display usage
usage() {
    echo "Usage: $0 --proxy-init-code <proxy init code (optional)>"
    exit 1
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --proxy-init-code) PROXY_INIT_CODE=$2; shift ;;
    esac
    shift
done

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropImplRegistry START"

registryInitCode="$(forge inspect contracts/registry/MagicDropTokenImplRegistry.sol:MagicDropTokenImplRegistry bytecode --optimizer-runs 777 --via-ir)"

if [ $PROXY_INIT_CODE ]; then
    echo "proxyInitCode: $PROXY_INIT_CODE"
    cast create2 --starts-with 00000000 --case-sensitive --init-code $PROXY_INIT_CODE
else
    echo "registryInitCode: $registryInitCode"
    cast create2 --starts-with 00000000 --case-sensitive --init-code $registryInitCode
fi

echo "create2 MagicDropImplRegistry END"
echo "-------------------------------------"
echo ""
