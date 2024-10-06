#!/bin/bash

set -e

rm -rf artifacts || true

for node in nethermind reth geth; do
    echo "Building $node"

    rm -rf "${node}-artifacts" || true

    sed -i "s/nethermind|reth|geth/${node}/g" patches/post/cvm-initramfs.bb/cvm-initramfs.bb.new

    make azure-image
    
    mv artifacts "${node}-artifacts"
done
