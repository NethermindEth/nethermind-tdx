#!/bin/bash
# Install rustup and the Rust 1.93 toolchain into $BUILDDIR/rust (persistent
# across mkosi rebuilds). Called once from mkosi.build before service builds.
set -euxo pipefail

export RUSTUP_HOME="$BUILDDIR/rust/rustup"
export CARGO_HOME="$BUILDDIR/rust/cargo"
export PATH="$CARGO_HOME/bin:$PATH"

if [ ! -x "$CARGO_HOME/bin/rustup" ]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --no-modify-path --default-toolchain none
fi

if ! rustup toolchain list | grep -q '^1\.93'; then
    rustup toolchain install 1.93 --profile minimal
fi
