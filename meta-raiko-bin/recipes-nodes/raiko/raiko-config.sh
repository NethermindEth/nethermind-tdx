#!/bin/bash

# Raiko TDX configuration functions
# Adapted from Docker entrypoint for non-container use

RAIKO_CONF_DIR="/etc/raiko"
RAIKO_DATA_DIR="/persistent/raiko"
RAIKO_CHAIN_SPECS="$RAIKO_CONF_DIR/chain_spec_list.json"

function update_chain_spec_json() {
    CONFIG_FILE=$1
    CHAIN_NAME=$2
    KEY_NAME=$3
    UPDATE_VALUE=$4
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Warning: $CONFIG_FILE file not found."
        return 1
    fi
    
    jq \
        --arg update_value "$UPDATE_VALUE" \
        --arg chain_name "$CHAIN_NAME" \
        --arg key_name "$KEY_NAME" \
        'map(if .name == $chain_name then .[$key_name] = $update_value else . end)' "$CONFIG_FILE" \
        > /tmp/config_tmp.json && mv /tmp/config_tmp.json "$CONFIG_FILE"
    echo "Updated $CONFIG_FILE $CHAIN_NAME.$KEY_NAME=$UPDATE_VALUE"
}

function update_tdx_chain_specs() {
    CONFIG_FILE=$1
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Warning: chain_spec_list.json file not found at $CONFIG_FILE."
        return 1
    fi

    # Update Ethereum mainnet RPC if provided
    if [ -n "${RAIKO_ETHEREUM_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "ethereum" "rpc" "$RAIKO_ETHEREUM_RPC"
    fi

    # Update Ethereum mainnet beacon RPC if provided
    if [ -n "${RAIKO_ETHEREUM_BEACON_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "ethereum" "beacon_rpc" "$RAIKO_ETHEREUM_BEACON_RPC"
    fi

    # Update Holesky RPC if provided
    if [ -n "${RAIKO_HOLESKY_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "holesky" "rpc" "$RAIKO_HOLESKY_RPC"
    fi

    # Update Holesky beacon RPC if provided
    if [ -n "${RAIKO_HOLESKY_BEACON_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "holesky" "beacon_rpc" "$RAIKO_HOLESKY_BEACON_RPC"
    fi

    # Update Taiko A7 RPC if provided
    if [ -n "${RAIKO_TAIKO_A7_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "taiko_a7" "rpc" "$RAIKO_TAIKO_A7_RPC"
    fi

    # Update Taiko mainnet RPC if provided
    if [ -n "${RAIKO_TAIKO_MAINNET_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "taiko_mainnet" "rpc" "$RAIKO_TAIKO_MAINNET_RPC"
    fi

    # Update Surge dev L1 RPC if provided
    if [ -n "${RAIKO_SURGE_DEV_L1_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "surge_dev_l1" "rpc" "$RAIKO_SURGE_DEV_L1_RPC"
    fi

    # Update Surge dev L1 beacon RPC if provided
    if [ -n "${RAIKO_SURGE_DEV_L1_BEACON_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "surge_dev_l1" "beacon_rpc" "$RAIKO_SURGE_DEV_L1_BEACON_RPC"
    fi

    # Update Surge dev RPC if provided
    if [ -n "${RAIKO_SURGE_DEV_RPC}" ]; then
        update_chain_spec_json "$CONFIG_FILE" "surge_dev" "rpc" "$RAIKO_SURGE_DEV_RPC"
    fi
}

function prepare_tdx_config() {
    # Create necessary directories
    mkdir -p "$RAIKO_DATA_DIR"
    
    # Set default values with fallbacks from JSON config
    RAIKO_L1_NETWORK="${RAIKO_L1_NETWORK:-holesky}"
    RAIKO_NETWORK="${RAIKO_NETWORK:-surge_dev}"
    RAIKO_CHAIN_SPEC_PATH="${RAIKO_CHAIN_SPEC:-$RAIKO_CHAIN_SPECS}"
    RAIKO_LOG_LEVEL="${RAIKO_LOG_LEVEL:-info}"
    
    # Update chain specifications with provided RPC endpoints
    if [ -f "$RAIKO_CHAIN_SPEC_PATH" ]; then
        update_tdx_chain_specs "$RAIKO_CHAIN_SPEC_PATH"
    else
        echo "Warning: Chain spec file not found at $RAIKO_CHAIN_SPEC_PATH"
    fi
    
    # Export variables for use in init script
    export RAIKO_L1_NETWORK
    export RAIKO_NETWORK
    export RAIKO_CHAIN_SPEC_PATH
    export RAIKO_LOG_LEVEL
    export RAIKO_DATA_DIR
}