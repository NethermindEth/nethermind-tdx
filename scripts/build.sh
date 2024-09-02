#!/bin/bash

# Build script
# Can be used in either docker or local mode

set -e

# check if DOCKER_BUILD is set
if [ -z "$DOCKER_BUILD" ]; then
    echo "Building locally"
    DOCKER=false
    PATCHES_DIR=../patches

    cd ./build
else
    echo "Building in docker container"
    DOCKER=true
    PATCHES_DIR=/patches

    cd /build
fi
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
