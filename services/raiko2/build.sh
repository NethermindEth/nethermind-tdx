#!/bin/bash
# Build raiko2 from the local submodule at services/raiko2/src.
#
# raiko2 is currently a private repo, so it is vendored as a git submodule.
# Run `make submodules` before `make build` to populate / update the checkout.
#
# Binary + guest ELFs + chain spec are cached in $BUILDDIR by source revision
# (git commit + dirty hash) so repeated `mkosi --force` rebuilds skip the
# expensive cargo build.
set -euxo pipefail

LOCAL_SRC="services/raiko2/src"

if [ ! -d "$LOCAL_SRC" ] || [ -z "$(ls -A "$LOCAL_SRC" 2>/dev/null)" ]; then
    echo "ERROR: raiko2 source not found at $LOCAL_SRC."
    echo "  Run: make submodules"
    exit 1
fi

# Cache key: short commit + hash of any uncommitted changes.
RAIKO2_VERSION=$(git -C "$LOCAL_SRC" rev-parse --short HEAD 2>/dev/null \
    || sha256sum "$LOCAL_SRC/Cargo.lock" | cut -c1-16)
if ! git -C "$LOCAL_SRC" diff --quiet HEAD 2>/dev/null; then
    DIRTY=$(git -C "$LOCAL_SRC" diff HEAD | sha256sum | cut -c1-8)
    RAIKO2_VERSION="${RAIKO2_VERSION}-${DIRTY}"
fi

CACHED_BIN="$BUILDDIR/raiko2-bin-${RAIKO2_VERSION}"
CACHED_ELF="$BUILDDIR/raiko2-elf-${RAIKO2_VERSION}"
CACHED_SPEC="$BUILDDIR/raiko2-spec-${RAIKO2_VERSION}.json"

mkdir -p "$DESTDIR/usr/bin" \
         "$DESTDIR/usr/share/raiko2/elf" \
         "$DESTDIR/etc/raiko2" \
         "$DESTDIR/home/raiko2"

if [ -f "$CACHED_BIN" ] && [ -d "$CACHED_ELF" ] && [ -f "$CACHED_SPEC" ]; then
    echo "Using cached raiko2 artifacts (version $RAIKO2_VERSION)"
else
    BUILD_STAGE="$BUILDROOT/build/raiko2"
    rm -rf "$BUILD_STAGE"
    mkdir -p "$BUILD_STAGE"
    cp -a "$LOCAL_SRC/." "$BUILD_STAGE/"

    # Restore cargo/rustup/target caches from $BUILDDIR if present.
    CARGO_CACHE="$BUILDDIR/raiko2-cargo"
    RUSTUP_CACHE="$BUILDDIR/raiko2-rustup"
    TARGET_CACHE="$BUILDDIR/raiko2-target"
    if [ -d "$CARGO_CACHE" ]; then
        mkdir -p "$BUILDROOT/build/.cargo"
        cp -a "$CARGO_CACHE/." "$BUILDROOT/build/.cargo/"
    fi
    if [ -d "$RUSTUP_CACHE" ]; then
        mkdir -p "$BUILDROOT/build/.rustup"
        cp -a "$RUSTUP_CACHE/." "$BUILDROOT/build/.rustup/"
    fi
    if [ -d "$TARGET_CACHE" ]; then
        mkdir -p "$BUILD_STAGE/target"
        cp -a "$TARGET_CACHE/." "$BUILD_STAGE/target/"
    fi

    RUSTFLAGS=(
        "-C target-cpu=generic"
        "-C link-arg=-Wl,--build-id=none"
        "-C symbol-mangling-version=v0"
        "-L /usr/lib/x86_64-linux-gnu"
    )
    RUSTFLAGS_STR="${RUSTFLAGS[*]}"

    mkosi-chroot bash <<CHROOT_EOF
set -euxo pipefail

export RUSTUP_HOME='/build/.rustup'
export CARGO_HOME='/build/.cargo'
export PATH="\$CARGO_HOME/bin:\$PATH"

if [ ! -x "\$CARGO_HOME/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --default-toolchain none
fi

export RUSTFLAGS='$RUSTFLAGS_STR'
export CARGO_PROFILE_RELEASE_LTO='thin'
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS='1'
export CARGO_PROFILE_RELEASE_PANIC='abort'
export CARGO_PROFILE_RELEASE_INCREMENTAL='true'
export CARGO_PROFILE_RELEASE_OPT_LEVEL='3'
export CARGO_TERM_COLOR='never'

cd /build/raiko2
rustup show
cargo fetch
cargo build --release --bin raiko2 --features tdx
CHROOT_EOF

    # Save caches back. find -type d so broken symlinks in checkouts don't abort.
    mkdir -p "$CARGO_CACHE" "$RUSTUP_CACHE" "$TARGET_CACHE"
    for _cache_dir in "$CARGO_CACHE" "$RUSTUP_CACHE" "$TARGET_CACHE"; do
        find "$_cache_dir" -type d -exec chmod u+w {} + 2>/dev/null || true
    done
    rm -rf "$CARGO_CACHE" "$RUSTUP_CACHE"
    mkdir -p "$CARGO_CACHE" "$RUSTUP_CACHE"
    cp -a "$BUILDROOT/build/.cargo/." "$CARGO_CACHE/"
    cp -a "$BUILDROOT/build/.rustup/." "$RUSTUP_CACHE/"
    rm -rf "$TARGET_CACHE"
    mkdir -p "$TARGET_CACHE"
    cp -a "$BUILD_STAGE/target/." "$TARGET_CACHE/"

    install -m 755 "$BUILD_STAGE/target/release/raiko2" "$CACHED_BIN"
    rm -rf "$CACHED_ELF"
    mkdir -p "$CACHED_ELF"
    cp -a "$BUILD_STAGE/crates/guests/elf/." "$CACHED_ELF/"
    install -m 644 "$BUILD_STAGE/config/chain_spec_list_default.json" "$CACHED_SPEC"
fi

# Install into the image.
install -m 755 "$CACHED_BIN" "$DESTDIR/usr/bin/raiko2"
cp -a "$CACHED_ELF/." "$DESTDIR/usr/share/raiko2/elf/"
install -m 644 "$CACHED_SPEC" "$DESTDIR/etc/raiko2/chain_spec_list.json"
install -d -m 0750 "$DESTDIR/home/raiko2"
#!/bin/bash
# Build raiko2 from git, mirroring the pattern used by services/raiko/build.sh.
# Version/URL are pinned by the calling variant's mkosi.build
# (see taiko-tdx-prover/mkosi.build). Fall back to taiko defaults.
#
# Cached artifacts (binary + guest ELFs + chain spec) live in $BUILDDIR keyed
# by the git ref, so repeated mkosi --force rebuilds skip recompilation.
set -euxo pipefail

RAIKO2_VERSION="${RAIKO2_VERSION:-feat/tdx-prover}"
RAIKO2_GIT_URL="${RAIKO2_GIT_URL:-https://github.com/taikoxyz/raiko2.git}"

SAFE_VERSION="${RAIKO2_VERSION//\//_}"
CACHED_BIN="$BUILDDIR/raiko2-bin-${SAFE_VERSION}"
CACHED_ELF="$BUILDDIR/raiko2-elf-${SAFE_VERSION}"
CACHED_SPEC="$BUILDDIR/raiko2-spec-${SAFE_VERSION}.json"

mkdir -p "$DESTDIR/usr/bin" "$DESTDIR/usr/share/raiko2/elf" "$DESTDIR/etc/raiko2" "$DESTDIR/home/raiko2"

if [ -f "$CACHED_BIN" ] && [ -d "$CACHED_ELF" ] && [ -f "$CACHED_SPEC" ]; then
    echo "Using cached raiko2 artifacts (version $RAIKO2_VERSION)"
else
    BUILD_STAGE="$BUILDROOT/build/raiko2"
    rm -rf "$BUILD_STAGE"
    mkdir -p "$BUILD_STAGE"
    git clone --depth 1 --branch "$RAIKO2_VERSION" "$RAIKO2_GIT_URL" "$BUILD_STAGE"

    # Restore cargo/rustup/target caches from $BUILDDIR if present.
    CARGO_CACHE="$BUILDDIR/raiko2-cargo"
    RUSTUP_CACHE="$BUILDDIR/raiko2-rustup"
    TARGET_CACHE="$BUILDDIR/raiko2-target"
    if [ -d "$CARGO_CACHE" ]; then
        mkdir -p "$BUILDROOT/build/.cargo"
        cp -a "$CARGO_CACHE/." "$BUILDROOT/build/.cargo/"
    fi
    if [ -d "$RUSTUP_CACHE" ]; then
        mkdir -p "$BUILDROOT/build/.rustup"
        cp -a "$RUSTUP_CACHE/." "$BUILDROOT/build/.rustup/"
    fi
    if [ -d "$TARGET_CACHE" ]; then
        mkdir -p "$BUILD_STAGE/target"
        cp -a "$TARGET_CACHE/." "$BUILD_STAGE/target/"
    fi

    RUSTFLAGS=(
        "-C target-cpu=generic"
        "-C link-arg=-Wl,--build-id=none"
        "-C symbol-mangling-version=v0"
        "-L /usr/lib/x86_64-linux-gnu"
    )
    RUSTFLAGS_STR="${RUSTFLAGS[*]}"

    mkosi-chroot bash <<CHROOT_EOF
set -euxo pipefail

export RUSTUP_HOME='/build/.rustup'
export CARGO_HOME='/build/.cargo'
export PATH="\$CARGO_HOME/bin:\$PATH"

if [ ! -x "\$CARGO_HOME/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --default-toolchain none
fi

export RUSTFLAGS='$RUSTFLAGS_STR'
export CARGO_PROFILE_RELEASE_LTO='thin'
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS='1'
export CARGO_PROFILE_RELEASE_PANIC='abort'
export CARGO_PROFILE_RELEASE_INCREMENTAL='true'
export CARGO_PROFILE_RELEASE_OPT_LEVEL='3'
export CARGO_TERM_COLOR='never'

cd /build/raiko2
rustup show
cargo fetch
cargo build --release --bin raiko2 --features tdx
CHROOT_EOF

    # Save cargo/rustup/target caches back. Use find -type d so broken symlinks
    # in source checkouts don't abort the script.
    mkdir -p "$CARGO_CACHE" "$RUSTUP_CACHE" "$TARGET_CACHE"
    for _cache_dir in "$CARGO_CACHE" "$RUSTUP_CACHE" "$TARGET_CACHE"; do
        find "$_cache_dir" -type d -exec chmod u+w {} + 2>/dev/null || true
    done
    rm -rf "$CARGO_CACHE" "$RUSTUP_CACHE"
    mkdir -p "$CARGO_CACHE" "$RUSTUP_CACHE"
    cp -a "$BUILDROOT/build/.cargo/." "$CARGO_CACHE/"
    cp -a "$BUILDROOT/build/.rustup/." "$RUSTUP_CACHE/"
    rm -rf "$TARGET_CACHE"
    mkdir -p "$TARGET_CACHE"
    cp -a "$BUILD_STAGE/target/." "$TARGET_CACHE/"

    install -m 755 "$BUILD_STAGE/target/release/raiko2" "$CACHED_BIN"
    rm -rf "$CACHED_ELF"
    mkdir -p "$CACHED_ELF"
    cp -a "$BUILD_STAGE/crates/guests/elf/." "$CACHED_ELF/"
    install -m 644 "$BUILD_STAGE/config/chain_spec_list_default.json" "$CACHED_SPEC"
fi

# Install into the image.
install -m 755 "$CACHED_BIN" "$DESTDIR/usr/bin/raiko2"
cp -a "$CACHED_ELF/." "$DESTDIR/usr/share/raiko2/elf/"
install -m 644 "$CACHED_SPEC" "$DESTDIR/etc/raiko2/chain_spec_list.json"
install -d -m 0750 "$DESTDIR/home/raiko2"
#!/bin/bash
# Build raiko2 from local source staged at services/raiko2/src.
# Binary and guest ELFs are cached in $BUILDDIR by source version so that
# repeated mkosi --force rebuilds skip recompilation.
set -euxo pipefail

LOCAL_SRC="services/raiko2/src"

if [ ! -d "$LOCAL_SRC" ]; then
    echo "ERROR: raiko2 source not found at $LOCAL_SRC."
    echo "  Re-run: make build IMAGE=surge-tdx-prover"
    exit 1
fi

# Cache key: git commit + hash of any uncommitted changes, so edits without a
# commit still invalidate the cache. Falls back to Cargo.lock hash if not git.
RAIKO2_VERSION=$(git -C "$LOCAL_SRC" rev-parse --short HEAD 2>/dev/null \
    || sha256sum "$LOCAL_SRC/Cargo.lock" | cut -c1-16)
if git -C "$LOCAL_SRC" diff --quiet HEAD 2>/dev/null; then
    : # clean tree — commit hash is sufficient
else
    DIRTY=$(git -C "$LOCAL_SRC" diff HEAD | sha256sum | cut -c1-8)
    RAIKO2_VERSION="${RAIKO2_VERSION}-${DIRTY}"
fi

CACHED_BIN="$BUILDDIR/raiko2-bin-${RAIKO2_VERSION}"
CACHED_ELF="$BUILDDIR/raiko2-elf-${RAIKO2_VERSION}"

mkdir -p "$DESTDIR/usr/bin" "$DESTDIR/usr/share/raiko2/elf" "$DESTDIR/etc/raiko2" "$DESTDIR/home/raiko2"

if [ -f "$CACHED_BIN" ] && [ -d "$CACHED_ELF" ]; then
    echo "Using cached raiko2 binary (version $RAIKO2_VERSION)"
else
    # Stage source in the chroot build dir.
    BUILD_STAGE="$BUILDROOT/build/raiko2"
    mkdir -p "$BUILD_STAGE"
    cp -a "$LOCAL_SRC/." "$BUILD_STAGE/"

    # Restore cargo/rustup caches from $BUILDDIR if present.
    CARGO_CACHE="$BUILDDIR/raiko2-cargo"
    RUSTUP_CACHE="$BUILDDIR/raiko2-rustup"
    TARGET_CACHE="$BUILDDIR/raiko2-target"
    if [ -d "$CARGO_CACHE" ]; then
        mkdir -p "$BUILDROOT/build/.cargo"
        cp -a "$CARGO_CACHE/." "$BUILDROOT/build/.cargo/"
    fi
    if [ -d "$RUSTUP_CACHE" ]; then
        mkdir -p "$BUILDROOT/build/.rustup"
        cp -a "$RUSTUP_CACHE/." "$BUILDROOT/build/.rustup/"
    fi
    if [ -d "$TARGET_CACHE" ]; then
        mkdir -p "$BUILD_STAGE/target"
        cp -a "$TARGET_CACHE/." "$BUILD_STAGE/target/"
    fi

    RUSTFLAGS=(
        "-C target-cpu=generic"
        "-C link-arg=-Wl,--build-id=none"
        "-C symbol-mangling-version=v0"
        "-L /usr/lib/x86_64-linux-gnu"
    )
    RUSTFLAGS_STR="${RUSTFLAGS[*]}"

    mkosi-chroot bash <<CHROOT_EOF
set -euxo pipefail

export RUSTUP_HOME='/build/.rustup'
export CARGO_HOME='/build/.cargo'
export PATH="\$CARGO_HOME/bin:\$PATH"

if [ ! -x "\$CARGO_HOME/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --default-toolchain none
fi

export RUSTFLAGS='$RUSTFLAGS_STR'
export CARGO_PROFILE_RELEASE_LTO='thin'
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS='1'
export CARGO_PROFILE_RELEASE_PANIC='abort'
export CARGO_PROFILE_RELEASE_INCREMENTAL='true'
export CARGO_PROFILE_RELEASE_OPT_LEVEL='3'
export CARGO_TERM_COLOR='never'

cd /build/raiko2
rustup show
cargo fetch
cargo build --release --bin raiko2 --features tdx
CHROOT_EOF

    # Save cargo/rustup/target caches back. Use find -type d to chmod only real
    # directories so broken symlinks in git checkouts don't abort the script.
    mkdir -p "$CARGO_CACHE" "$RUSTUP_CACHE" "$TARGET_CACHE"
    for _cache_dir in "$CARGO_CACHE" "$RUSTUP_CACHE" "$TARGET_CACHE"; do
        find "$_cache_dir" -type d -exec chmod u+w {} + 2>/dev/null || true
    done
    rm -rf "$CARGO_CACHE" "$RUSTUP_CACHE"
    mkdir -p "$CARGO_CACHE" "$RUSTUP_CACHE"
    cp -a "$BUILDROOT/build/.cargo/." "$CARGO_CACHE/"
    cp -a "$BUILDROOT/build/.rustup/." "$RUSTUP_CACHE/"
    # Sync target dir incrementally (rsync-style with cp -u would be ideal but
    # cp -a is sufficient; only update if build produced a new target dir).
    rm -rf "$TARGET_CACHE"
    mkdir -p "$TARGET_CACHE"
    cp -a "$BUILD_STAGE/target/." "$TARGET_CACHE/"

    # Cache binary and guest ELFs by version.
    install -m 755 "$BUILD_STAGE/target/release/raiko2" "$CACHED_BIN"
    mkdir -p "$CACHED_ELF"
    cp -a "$BUILD_STAGE/crates/guests/elf/." "$CACHED_ELF/"
fi

# Install into the image.
install -m 755 "$CACHED_BIN" "$DESTDIR/usr/bin/raiko2"
cp -a "$CACHED_ELF/." "$DESTDIR/usr/share/raiko2/elf/"
install -m 644 "$LOCAL_SRC/config/chain_spec_list_default.json" \
    "$DESTDIR/etc/raiko2/chain_spec_list.json"
install -d -m 0750 "$DESTDIR/home/raiko2"
