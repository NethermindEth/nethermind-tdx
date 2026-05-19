#!/bin/bash
set -euxo pipefail

source scripts/build_rust_package.sh

RAIKO2_VERSION="${RAIKO2_VERSION:-feat/tdx-prover}"
RAIKO2_GIT_URL="${RAIKO2_GIT_URL:-https://github.com/taikoxyz/raiko2.git}"

SAFE_VERSION="${RAIKO2_VERSION//\//_}"
CACHED_BIN="$BUILDDIR/raiko2-${SAFE_VERSION}"
CACHED_ELF="$BUILDDIR/raiko2-elf-${SAFE_VERSION}"
CACHED_SPEC="$BUILDDIR/raiko2-spec-${SAFE_VERSION}.json"

# All three artifacts must exist together. If ELFs or spec are missing,
# drop the binary cache so build_rust_package triggers a fresh clone+build.
if [ ! -d "$CACHED_ELF" ] || [ ! -f "$CACHED_SPEC" ]; then
    rm -f "$CACHED_BIN"
fi

# Build and cache the binary (same pattern as services/raiko/build.sh).
build_rust_package \
    "raiko2" \
    "$RAIKO2_VERSION" \
    "$RAIKO2_GIT_URL" \
    "" \
    "tdx" \
    "" \
    "raiko2"

# Cache guest ELFs and chain spec alongside the binary.
# build_rust_package skips cloning on a cache hit, so this block is only
# reached when the build actually ran and $BUILDROOT/build/raiko2 exists.
if [ ! -d "$CACHED_ELF" ] || [ ! -f "$CACHED_SPEC" ]; then
    BUILD_STAGE="$BUILDROOT/build/raiko2"
    rm -rf "$CACHED_ELF" && mkdir -p "$CACHED_ELF"
    cp -r "$BUILD_STAGE/crates/guests/elf/." "$CACHED_ELF/"
    install -m 644 "$BUILD_STAGE/config/chain_spec_list_default.json" "$CACHED_SPEC"
fi

mkdir -p "$DESTDIR/usr/share/raiko2/elf" "$DESTDIR/etc/raiko2"
cp -r "$CACHED_ELF/." "$DESTDIR/usr/share/raiko2/elf/"
install -m 644 "$CACHED_SPEC" "$DESTDIR/etc/raiko2/chain_spec_list.json"
install -d -m 0750 "$DESTDIR/home/raiko2"
