#!/bin/bash
# shared/config.sh

# Load .sbc.conf from /etc/vpn_hub if deployed, or relative paths for testing
CONFIG_FILE=".sbc.conf"
if [ -f "/etc/vpn_hub/.sbc.conf" ]; then
    CONFIG_FILE="/etc/vpn_hub/.sbc.conf"
elif [ -f "$(dirname "$0")/../.sbc.conf" ]; then
    CONFIG_FILE="$(dirname "$0")/../.sbc.conf"
elif [ -f "$(dirname "$0")/.sbc.conf" ]; then
    CONFIG_FILE="$(dirname "$0")/.sbc.conf"
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "[ERROR] Configuration file .sbc.conf not found!"
    exit 1
fi

# Source it safely
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ $key =~ ^#.*$ ]] && continue
    [[ -z $key ]] && continue
    # Remove carriage returns if any
    value=$(echo "$value" | tr -d '\r')
    export "$key=$value"
done < "$CONFIG_FILE"
