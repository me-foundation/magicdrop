#! /bin/bash

brew install libusb

# install dependencies
curl -L https://foundry.paradigm.xyz | bash

if [ -f ~/.zshenv ]; then
    source ~/.zshenv
fi

foundryup

# install gum
brew install gum

# install jq
brew install jq

git pull

# install forge dependencies
forge install
# build contracts
forge build

echo ""
echo "Done"
echo "Run './magicdrop' to start"
echo ""