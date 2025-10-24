#!/bin/bash
set -euxo pipefail

source scripts/build_dotnet_package.sh

NETHERMIND_VERSION="1.32.3"
NETHERMIND_GIT_URL="https://github.com/NethermindEth/nethermind.git"
NETHERMIND_BINARY_PATH="/usr/bin/nethermind"
NETHERMIND_NLOG_CONFIG_PATH="/etc/nethermind-surge/NLog.config"
NETHERMIND_PLUGINS_PATH="/etc/nethermind-surge/plugins"

build_dotnet_package \
    "nethermind" \
    "$NETHERMIND_VERSION" \
    "$NETHERMIND_GIT_URL" \
    "src/Nethermind/Nethermind.Runner" \
    ""\
    "" \
    "publish/nethermind:$NETHERMIND_BINARY_PATH" \
    "publish/NLog.config:$NETHERMIND_NLOG_CONFIG_PATH" \
    "publish/plugins:$NETHERMIND_PLUGINS_PATH"
