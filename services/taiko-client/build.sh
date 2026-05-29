#!/bin/bash
set -euxo pipefail

source scripts/make_git_package.sh

# Version + URL are pinned by the calling variant's mkosi.build (see
# {surge,taiko}-tdx-prover/mkosi.build). Fall back to taiko defaults.
TAIKO_CLIENT_VERSION="${TAIKO_CLIENT_VERSION:-main}"
TAIKO_CLIENT_GIT_URL="${TAIKO_CLIENT_GIT_URL:-https://github.com/taikoxyz/taiko-mono/}"
TAIKO_CLIENT_BINARY_PATH="/usr/bin/taiko-client"

make_git_package \
    "taiko-client" \
    "$TAIKO_CLIENT_VERSION" \
    "$TAIKO_CLIENT_GIT_URL" \
    'cd packages/taiko-client && GO111MODULE=on CGO_CFLAGS="-O -D__BLST_PORTABLE__" CGO_CFLAGS_ALLOW="-O -D__BLST_PORTABLE__" go build -trimpath -ldflags "-s -w -buildid=" -o bin/taiko-client cmd/main.go' \
    "packages/taiko-client/bin/taiko-client:$TAIKO_CLIENT_BINARY_PATH"