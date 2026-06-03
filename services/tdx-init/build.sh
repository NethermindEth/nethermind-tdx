#!/bin/bash
set -euxo pipefail

source scripts/make_git_package.sh

# TODO: revert to "main" once the NVMe disk-detection fix (59b8704) is merged.
# Pinned to a feat/taiko-raiko2 commit so GCP builds pick up the NVMe fix.
TDX_INIT_VERSION="59b8704807b175d21ecb9b007b13f193b563bc15"
TDX_INIT_GIT_URL="https://github.com/NethermindEth/nethermind-tdx"
TDX_INIT_BINARY_PATH="/usr/bin/tdx-init"

make_git_package \
    "tdx-init" \
    "$TDX_INIT_VERSION" \
    "$TDX_INIT_GIT_URL" \
    'cd init && go build -trimpath -ldflags "-s -w -buildid=" -o ./build/tdx-init ./cmd/main.go' \
    "init/build/tdx-init:$TDX_INIT_BINARY_PATH"
