#!/bin/bash

# Script to setup raiko binary and config files

set -e

if [ ! -d "raiko" ]; then
    git clone https://github.com/NethermindEth/raiko -b feat/tdx
fi

cd raiko

# Use the specific nightly toolchain and build parameters as specified
RUSTFLAGS="-C target-feature=+crt-static" cargo +nightly-2024-09-05 build --target x86_64-unknown-linux-gnu --release --features tdx -p raiko-host -F raiko-tasks/in-memory

# Copy the binary
cp target/x86_64-unknown-linux-gnu/release/raiko-host ../meta-raiko-bin/recipes-nodes/raiko/raiko

# Copy configuration files (if they exist in the raiko repo)
# Copy the default chain spec list if it exists
if [ -f "host/config/chain_spec_list_default.json" ]; then
    cp host/config/chain_spec_list_default.json ../meta-raiko-bin/recipes-nodes/raiko/chain_spec_list_default.json
fi

# TODO: Add TDX-specific config file copying when provided