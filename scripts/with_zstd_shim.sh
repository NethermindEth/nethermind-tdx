#!/usr/bin/env bash
# Wrapper that prepends scripts/wrappers/ (containing a zstd shim) to PATH
# and injects --extra-search-path into mkosi commands so mkosi's sandbox
# uses the Nix-installed zstd. Without this, mkosi falls back to whatever
# /usr/bin/zstd the host distro ships, which differs between Debian trixie
# (1.5.7) and Ubuntu 24.04 (1.5.5) and produces different compressed bytes
# for the same input — breaking cross-host reproducibility.
#
# Usage: with_zstd_shim.sh <command> [args...]
set -e

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export PATH="$HERE/wrappers:$PATH"
export ZSTD_NBTHREADS=1

# Locate the Nix-installed zstd. `command -v zstd` resolves via PATH which,
# inside `nix develop`, points at the flake-pinned zstd derivation. Skip the
# injection if zstd ends up under /usr — mkosi's path parser rejects /usr
# entries by design.
if [ "$#" -gt 0 ]; then
    case "$1" in
        mkosi|*/mkosi)
            ZSTD_BIN="$(command -v zstd 2>/dev/null || true)"
            if [ -n "$ZSTD_BIN" ]; then
                ZSTD_DIR="$(dirname "$(readlink -f "$ZSTD_BIN")")"
                case "$ZSTD_DIR" in
                    /usr/*) ;;
                    *) set -- "$1" "--extra-search-path=$ZSTD_DIR" "${@:2}" ;;
                esac
            fi
            ;;
    esac
fi

exec "$@"
