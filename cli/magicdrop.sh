#!/usr/bin/env bash

source ./cmds/main_menu.sh

load_defaults

# Run the menu only if the configuration is complete
if [[ "$CONFIG_COMPLETE" == true ]]; then
    main_menu
else
    echo "Configuration is incomplete. Please ensure all values are set in defaults.json."
fi
