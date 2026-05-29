#!/bin/bash
# Build the reth-tdx remote TDX prover binary and install it as /usr/bin/reth-tdx.
# Clones the upstream repo at the pin set in taiko-tdx-prover/mkosi.build
# (RETH_TDX_VERSION / RETH_TDX_GIT_URL).
set -euxo pipefail

source scripts/build_rust_package.sh

RETH_TDX_VERSION="${RETH_TDX_VERSION:-main}"
RETH_TDX_GIT_URL="${RETH_TDX_GIT_URL:-https://github.com/NethermindEth/reth-tdx.git}"

build_rust_package \
    "reth-tdx" \
    "$RETH_TDX_VERSION" \
    "$RETH_TDX_GIT_URL" \
    "" \
    "" \
    "" \
    "reth-tdx"

install -d -m 0750 "$DESTDIR/home/reth-tdx"
