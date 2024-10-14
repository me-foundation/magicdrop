#! /bin/bash

# install dependencies
curl -L https://foundry.paradigm.xyz | bash

if [ -f ~/.zshenv ]; then
    source ~/.zshenv
fi

# install gum
brew install gum

# install jq
brew install jq

