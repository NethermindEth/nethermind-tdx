#!/usr/bin/env bash
# Wrapper that prepends scripts/wrappers/ (containing a zstd shim) to PATH
# before invoking the requested command. Used to force single-threaded zstd
# inside the mkosi build environment without fighting `bash -c` quoting.
#
# Usage: with_zstd_shim.sh <command> [args...]
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
export PATH="$HERE/wrappers:$PATH"
export ZSTD_NBTHREADS=1
exec "$@"
