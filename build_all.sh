#!/bin/bash

set -e

rm -rf artifacts || true

for node in nethermind reth geth; do
    echo "Building $node"

    rm -rf "${node}-artifacts" || true

    sed -i "s/\(PACKAGE_INSTALL = \".*\)\(nethermind\|reth\|geth\)\(.*\)\"/\1${node}\3\"/" patches/post/cvm-initramfs.bb/cvm-initramfs.bb.new

    make azure-image
    
    mv artifacts "${node}-artifacts"
done
