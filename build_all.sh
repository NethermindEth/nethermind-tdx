#!/bin/bash

set -e

rm -rf artifacts

for node in geth nethermind reth; do
    echo "Building $node"

    rm -rf "${node}-artifacts"

    sed -i "s/nethermind|reth|geth/${node}/g" patches/post/cvm-initramfs.bb/cvm-initramfs.bb.new

    mv artifacts "${node}-artifacts"
done
