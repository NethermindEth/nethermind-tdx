#!/usr/bin/env bash
# When invoking mkosi, inject `--extra-search-path=<dir>` pointing at the
# Nix-installed zstd's bin directory. mkosi's bwrap sandbox uses
# extra-search-path entries when resolving binaries, so this makes mkosi
# pick the SAME zstd version on every host regardless of what the host
# distro ships at /usr/bin/zstd (Lima Debian trixie has 1.5.7, the GH
# Ubuntu 24.04 runner has 1.5.5 — two versions produce different
# compressed bytes for the same input, breaking PCR reproducibility).
#
# Requires the flake.nix devShell to expose zstd via nativeBuildInputs so
# `command -v zstd` resolves to the Nix-pinned binary inside `nix develop`.
#
# Usage: with_zstd_shim.sh <command> [args...]
set -e

export ZSTD_NBTHREADS=1

if [ "$#" -gt 0 ]; then
    case "$1" in
        mkosi|*/mkosi)
            ZSTD_BIN="$(command -v zstd 2>/dev/null || true)"
            ZSTD_DIR=""
            if [ -n "$ZSTD_BIN" ]; then
                ZSTD_DIR="$(dirname "$(readlink -f "$ZSTD_BIN")")"
            fi
            echo "[with_zstd_shim] zstd=$ZSTD_BIN dir=$ZSTD_DIR" >&2
            case "$ZSTD_DIR" in
                ""|/usr/*)
                    echo "[with_zstd_shim] not injecting --extra-search-path (empty or /usr)" >&2
                    ;;
                *)
                    echo "[with_zstd_shim] injecting --extra-search-path=$ZSTD_DIR" >&2
                    set -- "$1" "--extra-search-path=$ZSTD_DIR" "${@:2}"
                    ;;
            esac
            ;;
    esac
fi

exec "$@"
