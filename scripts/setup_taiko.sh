#!/bin/bash

set -e

if [ ! -d "taiko-mono" ]; then
    git clone --depth 1 https://github.com/taikoxyz/taiko-mono
fi

cd taiko-mono/packages/taiko-client

make build

cp bin/taiko-client ../../../meta-taiko-client/recipes-nodes/taiko-client/taiko-client
