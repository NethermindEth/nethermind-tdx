#!/bin/bash

# Script to setup git on a container

set -e

git clone https://github.com/sigp/lighthouse
cd lighthouse
RUSTFLAGS="-C target-feature=+crt-static" cargo build --target x86_64-unknown-linux-gnu --release
