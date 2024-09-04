#!/bin/bash

# Build script
# Can be used in either docker or local mode

set -e

if [ -z "$DOCKER_BUILD" ]; then
    echo "Building locally"

    DOCKER=false
    PATCHES_DIR=../patches
    ARTIFACTS_DIR=../artifacts
    META_NETHERMIND_DIR=../meta-nethermind
    META_LIGHTHOUSE_DIR=../meta-lighthouse-bin

    cd ./build
else
    echo "Building in docker container"

    DOCKER=true
    PATCHES_DIR=/patches
    ARTIFACTS_DIR=/artifacts
    META_NETHERMIND_DIR=/meta-nethermind
    META_LIGHTHOUSE_DIR=/meta-lighthouse-bin

    cd /build
fi

repo init -u https://github.com/flashbots/yocto-manifests.git -b tdx-rbuilder

# Apply pre-sync patches
for patch_dir in $PATCHES_DIR/pre/*; do
    patch_base="$patch_dir/$(basename "$patch_dir")"
    patch_target=$(cat "$patch_base.path")

    if ! diff -q $patch_target "$patch_base.new"; then
        patch $patch_target < $patch_base.patch
    fi
done

repo sync

# Apply post-sync patches
for patch_dir in $PATCHES_DIR/post/*; do
    patch_base="$patch_dir/$(basename "$patch_dir")"
    patch_target=$(cat "$patch_base.path")

    if ! diff -q $patch_target "$patch_base.new"; then
        patch $patch_target < $patch_base.patch
    fi
done

# Copy in meta-nethermind
rm -rf srcs/poky/meta-nethermind
cp -r $META_NETHERMIND_DIR srcs/poky/meta-nethermind

# Copy in meta-lighthouse
rm -rf srcs/poky/meta-lighthouse
cp -r $META_LIGHTHOUSE_DIR srcs/poky/meta-lighthouse

source setup
make build || true

# Copy artifacts to artifacts directory
cp --dereference srcs/poky/build/tmp/deploy/images/tdx/* $ARTIFACTS_DIR/.
