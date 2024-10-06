#!/bin/bash

set -e

if [ -z "$ALLOWED_IP" ]; then
    echo "ALLOWED_IP is not set"
    exit 1
fi

for node in nethermind reth geth; do
    echo "Deploying $node"

    make deploy-azure DISK_PATH="${node}-artifacts/dev/cvm-image-azure-tdx.rootfs.wic.vhd" ALLOWED_IP=${ALLOWED_IP} VM_NAME=test-${node} CONFIG_PATH=./config.json
done
