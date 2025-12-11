#!/bin/bash
set -euxo pipefail

source scripts/make_git_package.sh

TDXS_VERSION="master"
TDXS_GIT_URL="https://github.com/Hyodar/tdxs"
TDXS_BINARY_PATH="/usr/bin/tdxs"

make_git_package \
    "tdxs" \
    "$TDXS_VERSION" \
    "$TDXS_GIT_URL" \
    'make sync-constellation && go build -trimpath -ldflags "-s -w -buildid=" -o ./build/tdxs ./cmd/tdxs/main.go' \
    "build/tdxs:$TDXS_BINARY_PATH"