#!/bin/bash

if [ -f .env ]
then
  export $(grep -v '^#' .env | xargs)
else
    echo "Please set your .env file"
    exit 1
fi

# Function to display usage
usage() {
    echo "Usage: $0 --impl <path to implementation>"
    exit 1
}

# Process arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --impl) IMPL_PATH=$2; shift ;;
        *) usage ;;
    esac
    shift
done

# Check if all parameters are set
if [ -z "$IMPL_PATH" ]; then
    usage
fi

# NOTE: If you change the number of optimizer runs, you must also change the number in the deploy script, otherwise the CREATE2 address will be different

echo "create2 MagicDropImpl START"
implCode="$(forge inspect $IMPL_PATH bytecode --optimizer-runs 777 --via-ir)"
implInitCode="$implCode"
cast create2 --starts-with 00000000 --case-sensitive --init-code $implInitCode
echo "create2 MagicDropImpl END"
echo "-------------------------------------"
echo ""
