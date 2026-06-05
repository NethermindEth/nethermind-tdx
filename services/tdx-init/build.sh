#!/bin/bash
set -euxo pipefail

source scripts/make_git_package.sh

# Pinned to feat/taiko-raiko2 commit that adds 'none' SSH strategy support.
TDX_INIT_VERSION="9c2c63d93e24181b031326466ae7a492ccba29a0"
TDX_INIT_GIT_URL="https://github.com/NethermindEth/nethermind-tdx"
TDX_INIT_BINARY_PATH="/usr/bin/tdx-init"

make_git_package \
    "tdx-init" \
    "$TDX_INIT_VERSION" \
    "$TDX_INIT_GIT_URL" \
    'cd init && go build -trimpath -ldflags "-s -w -buildid=" -o ./build/tdx-init ./cmd/main.go' \
    "init/build/tdx-init:$TDX_INIT_BINARY_PATH"
