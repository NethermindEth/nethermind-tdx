#!/bin/bash

# Build script
# Can be used in either docker or local mode

set -e

# check if DOCKER is set
if [ -z "$DOCKER" ]; then
    echo "Running locally"
    DOCKER=false
    BUILD_DIR=./build
    PATCHES_DIR=./patches
else
    echo "Running in docker"
    DOCKER=true
    BUILD_DIR=/build
    PATCHES_DIR=/patches
fi

cd $BUILD_DIR

repo init -u https://github.com/flashbots/yocto-manifests.git -b tdx-rbuilder

for patch_dir in $PATCHES_DIR/pre/*; do
    patch_base="$patch_dir/$(basename "$patch_dir")"
    patch_target=$(cat "$patch_base.path")

    if ! diff -q $patch_target "$patch_base.new"; then
        patch $patch_target < $patch_base.patch
    fi
done

repo sync

for patch_dir in $PATCHES_DIR/post/*; do
    patch_base="$patch_dir/$(basename "$patch_dir")"
    patch_target=$(cat "$patch_base.path")

    if ! diff -q $patch_target "$patch_base.new"; then
        patch $patch_target < $patch_base.patch
    fi
done

if ! $DOCKER; then
    rm -rf srcs/poky/meta-nethermind
    cp -r ../meta-nethermind srcs/poky/meta-nethermind
fi

source setup

make build || true

cp --dereference srcs/poky/build/tmp/deploy/images/tdx/* ../artifacts/.
