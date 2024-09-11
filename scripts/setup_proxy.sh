#!/bin/bash

# Setup script for cvm-reverse-proxy

set -e

if [ ! -d "cvm-reverse-proxy" ]; then
    git clone https://github.com/konvera/cvm-reverse-proxy
fi

go build -C cvm-reverse-proxy -o cvm-reverse-proxy
