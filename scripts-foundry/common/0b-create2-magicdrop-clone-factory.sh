#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropCloneFactory START"
factoryCode="$(forge inspect contracts/factory/MagicDropCloneFactory.sol:MagicDropCloneFactory bytecode --optimizer-runs 777 --via-ir)"
factoryInitCode="$factoryCode"
cast create2 --starts-with 0000 --case-sensitive --init-code $factoryInitCode
echo "create2 MagicDropCloneFactory END"
echo "-------------------------------------"
echo ""
