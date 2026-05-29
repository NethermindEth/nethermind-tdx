#!/bin/bash

build_rust_package() {
    local identifier="$1"
    local version="$2"
    local git_url="$3"
    local provided_binary="$4"
    local extra_features="${5:-}"
    local extra_rustflags="${6:-}"
    local workspace_package="${7:-}"

    # Parse identifier - can be "binary:package" or just "package"
    local binary_name="${identifier%%:*}"
    local package_name="${identifier#*:}"    
    if [ "$binary_name" = "$package_name" ]; then
        package_name="$identifier"
    fi

    local safe_version="${version//\//_}"

    local dest_path="$DESTDIR/usr/bin/$package_name"
    mkdir -p "$DESTDIR/usr/bin"

    # If binary path is provided, use it directly
    if [ -n "$provided_binary" ]; then
        echo "Using provided binary for $package_name"
        cp "$provided_binary" "$dest_path"
        return
    fi

    # If binary is cached, skip compilation
    local cached_binary="$BUILDDIR/${binary_name}-${safe_version}"
    if [ -f "$cached_binary" ]; then
        echo "Using cached binary for $binary_name version $version"
        cp "$cached_binary" "$dest_path"
        return
    fi

    # Clone the repository. `$version` is allowed to be either a branch name
    # or an exact commit SHA — `git clone --depth 1 --branch` only accepts the
    # former, so go through fetch+checkout which handles both.
    local build_dir="$BUILDROOT/build/$package_name"
    rm -rf "$build_dir"
    git init -q "$build_dir"
    git -C "$build_dir" remote add origin "$git_url"
    git -C "$build_dir" fetch --depth 1 origin "$version"
    git -C "$build_dir" checkout -q FETCH_HEAD

    # Define Rust flags for reproducibility
    local rustflags=(
        "-C target-cpu=generic"
        "-C link-arg=-Wl,--build-id=none"
        "-C symbol-mangling-version=v0"
        "-L /usr/lib/x86_64-linux-gnu"
    )

    # Build inside mkosi chroot. Use a heredoc so that:
    # - outer-shell variables ($package_name, $rustflags, etc.) expand now
    # - inner-shell variables (\$CARGO_HOME, \$PATH) expand inside the chroot
    mkosi-chroot bash << CHROOT_EOF
set -euxo pipefail
export RUSTUP_HOME='/build/.rustup'
export CARGO_HOME='/build/.cargo'
export PATH="\$CARGO_HOME/bin:\$PATH"
export RUSTFLAGS='${rustflags[*]} ${extra_rustflags}'
export CARGO_PROFILE_RELEASE_LTO='thin'
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS='1'
export CARGO_PROFILE_RELEASE_PANIC='abort'
export CARGO_PROFILE_RELEASE_INCREMENTAL='false'
export CARGO_PROFILE_RELEASE_OPT_LEVEL='3'
export CARGO_TERM_COLOR='never'
if [ ! -x "\$CARGO_HOME/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --default-toolchain none
fi
cd '/build/${package_name}'
rustup show
cargo fetch
cargo build --release --frozen ${extra_features:+--features ${extra_features}} ${workspace_package:+--package ${workspace_package}}
CHROOT_EOF

    # Cache and install the built binary
    install -m 755 "$build_dir/target/release/$binary_name" "$cached_binary"
    install -m 755 "$cached_binary" "$dest_path"
}