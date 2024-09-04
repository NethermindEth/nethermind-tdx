#!/bin/bash

# Script to setup git on a container

set -e

if [ ! -d "lighthouse" ]; then
    git clone https://github.com/sigp/lighthouse
fi

cd lighthouse

RUSTFLAGS="-C target-feature=+crt-static" cargo build --target x86_64-unknown-linux-gnu -p lighthouse --release

cp target/x86_64-unknown-linux-gnu/release/lighthouse ../meta-lighthouse-bin/recipes-nodes/lighthouse/lighthouse
