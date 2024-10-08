#!/bin/bash

if [ -f .env ]
then
  export $(cat .env | xargs) 
else
    echo "Please set your .env file"
    exit 1
fi

echo "create2 ERC1967Proxy START"
# https://github.com/Vectorized/solady/blob/main/src/utils/LibClone.sol#L90
cast create2 --starts-with 00000000 --case-sensitive --init-code-hash 0xaaa52c8cc8a0e3fd27ce756cc6b4e70c51423e9b597b11f32d3e49f8b1fc890d
echo "create2 ERC1967Proxy END"
echo "-------------------------------------"
echo ""
