#!/bin/bash
set -euxo pipefail

source scripts/build_rust_package.sh

RAIKO_VERSION="main"
RAIKO_GIT_URL="https://github.com/NethermindEth/raiko.git"

build_rust_package \
    "raiko-host:raiko" \
    "$RAIKO_VERSION" \
    "$RAIKO_GIT_URL" \
    "" \
    "tdx" \
    "" \
    "raiko-host"
