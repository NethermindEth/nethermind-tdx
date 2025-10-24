#!/bin/bash
set -euxo pipefail

source scripts/make_git_package.sh

TDX_INIT_VERSION="v0.0.1"
TDX_INIT_GIT_URL="https://github.com/Hyodar/tdx-init"
TDX_INIT_BINARY_PATH="/usr/bin/tdx-init"

make_git_package \
    "tdx-init" \
    "$TDX_INIT_VERSION" \
    "$TDX_INIT_GIT_URL" \
    'go build -trimpath -ldflags "-s -w -buildid=" -o ./build/tdx-init ./cmd/main.go' \
    "build/tdx-init:$TDX_INIT_BINARY_PATH"
