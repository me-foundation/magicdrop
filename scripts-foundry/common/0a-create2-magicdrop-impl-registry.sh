#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropImplRegistry START"
registryCode="$(forge inspect contracts/registry/MagicDropTokenImplRegistry.sol:MagicDropTokenImplRegistry bytecode --optimizer-runs 777 --via-ir)"
registryInitCode="$registryCode"
echo $registryCode
cast create2 --starts-with 0000 --case-sensitive --init-code $registryInitCode
echo "create2 MagicDropImplRegistry END"
echo "-------------------------------------"
echo ""
