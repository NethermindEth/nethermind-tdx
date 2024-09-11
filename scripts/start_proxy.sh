#!/bin/bash

# Start cvm-reverse-proxy script
# Starts a client proxy which uses the server reverse proxy to trigger remote
# attestation

set -e

if [ -z "$TARGET_DOMAIN" ]; then
    echo "Error: TARGET_DOMAIN is not set."
    exit 1
fi

./cvm-reverse-proxy/cvm-reverse-proxy -client \
    -listen-port ${PROXY_PORT:-4000} \
    -target-domain ${TARGET_DOMAIN} \
    -target-port ${TARGET_PORT:-8745} \
    -measurements ${MEASUREMENTS_PATH:-./artifacts/dev/measurements.json}
