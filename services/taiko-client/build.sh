#!/bin/bash
set -euxo pipefail

source scripts/make_git_package.sh

TAIKO_CLIENT_VERSION="feat/tdx-proving"
TAIKO_CLIENT_GIT_URL="https://github.com/NethermindEth/surge-taiko-mono/"
TAIKO_CLIENT_BINARY_PATH="/usr/bin/taiko-client"

make_git_package \
    "taiko-client" \
    "$TAIKO_CLIENT_VERSION" \
    "$TAIKO_CLIENT_GIT_URL" \
    'cd packages/taiko-client && GO111MODULE=on CGO_CFLAGS="-O -D__BLST_PORTABLE__" CGO_CFLAGS_ALLOW="-O -D__BLST_PORTABLE__" go build -trimpath -ldflags "-s -w -buildid=" -o bin/taiko-client cmd/main.go' \
    "packages/taiko-client/bin/taiko-client:$TAIKO_CLIENT_BINARY_PATH"
