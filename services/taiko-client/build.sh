#!/bin/bash
set -euxo pipefail

source scripts/make_git_package.sh

TAIKO_CLIENT_VERSION="main"
TAIKO_CLIENT_GIT_URL="https://github.com/NethermindEth/surge-taiko-mono/"
TAIKO_CLIENT_BINARY_PATH="/usr/bin/taiko-client"

make_git_package \
    "taiko-client" \
    "$TAIKO_CLIENT_VERSION" \
    "$TAIKO_CLIENT_GIT_URL" \
    "cd packages/taiko-client && make build" \
    "packages/taiko-client/bin/taiko-client:$TAIKO_CLIENT_BINARY_PATH"
