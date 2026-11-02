#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

patch_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/patches"
source_dir="${1:?Usage: apply-patches.sh <kernel-source>}"

for patch in "$patch_dir"/*.patch; do
    if git -C "$source_dir" apply --check "$patch" 2>/dev/null; then
        git -C "$source_dir" apply "$patch"
    elif git -C "$source_dir" apply --reverse --check "$patch" 2>/dev/null; then
        echo "Already applied: $(basename "$patch")"
    else
        echo "Cannot apply kernel patch: $patch" >&2
        exit 1
    fi
done
