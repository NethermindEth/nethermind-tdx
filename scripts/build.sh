#!/bin/bash

# Build script
# Can be used in either docker or local mode

set -e

if [ -z "$DOCKER_BUILD" ]; then
    echo "Building locally"

    DOCKER=false
    PATCHES_DIR=$(realpath patches)
    ARTIFACTS_DIR=$(realpath $ARTIFACTS_DIR)
    META_NETHERMIND_DIR=$(realpath meta-nethermind)
    META_LIGHTHOUSE_DIR=$(realpath meta-lighthouse-bin)
    META_JSON_CONFIG_DIR=$(realpath meta-json-config)
    META_ATTESTATION_DIR=$(realpath meta-attestation)
    META_TDX_ATTESTOR_DIR=$(realpath meta-tdx-attestor)

    cd "./$BUILD_DIR"
else
    echo "Building in docker container"

    DOCKER=true
    PATCHES_DIR=/patches
    ARTIFACTS_DIR="/$ARTIFACTS_DIR"
    META_NETHERMIND_DIR=/meta-nethermind
    META_LIGHTHOUSE_DIR=/meta-lighthouse-bin
    META_JSON_CONFIG_DIR=/meta-json-config
    META_ATTESTATION_DIR=/meta-attestation
    META_TDX_ATTESTOR_DIR=/meta-tdx-attestor

    cd "/$BUILD_DIR"
fi

# Based on the tdx-rbuilder branch
repo init -u https://github.com/flashbots/yocto-manifests.git -b 3e03f7223af84c4b687dda753e74734e5d2d8548

# Apply pre-sync patches
for patch_dir in $PATCHES_DIR/pre/*; do
    patch_base=$(find "$patch_dir" -name "*.old" | sed 's/\.old$//')
    patch_target=$(cat "$patch_base.path")

    if ! diff -q $patch_target "$patch_base.new"; then
        chmod +w $patch_target
        cp "$patch_base.new" $patch_target
    fi
done

repo sync

# Apply post-sync patches
for patch_dir in $PATCHES_DIR/post/*; do
    patch_base=$(find "$patch_dir" -name "*.old" | sed 's/\.old$//')
    patch_target=$(cat "$patch_base.path")

    if ! diff -q $patch_target "$patch_base.new"; then
        chmod +w $patch_target
        cp "$patch_base.new" $patch_target
    fi
done

# Copy in meta-nethermind
rm -rf srcs/poky/meta-nethermind
cp -r $META_NETHERMIND_DIR srcs/poky/meta-nethermind

# Copy in meta-lighthouse-bin
rm -rf srcs/poky/meta-lighthouse-bin
cp -r $META_LIGHTHOUSE_DIR srcs/poky/meta-lighthouse-bin

# Copy in meta-json-config
rm -rf srcs/poky/meta-json-config
cp -r $META_JSON_CONFIG_DIR srcs/poky/meta-json-config

# Copy in meta-attestation
rm -rf srcs/poky/meta-attestation
cp -r $META_ATTESTATION_DIR srcs/poky/meta-attestation

# Copy in meta-tdx-attestor
rm -rf srcs/poky/meta-tdx-attestor
cp -r $META_TDX_ATTESTOR_DIR srcs/poky/meta-tdx-attestor

source setup
make build || true

# Copy artifacts to artifacts directory
cp --dereference srcs/poky/build/tmp/deploy/images/tdx/* $ARTIFACTS_DIR/.

# Clean up .NET build processes if not in container
if [ "$DOCKER" = false ]; then
    pkill -f MSBuild.dll || true
    pkill -f VBCSCompiler.dll || true
fi
