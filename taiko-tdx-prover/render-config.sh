#!/bin/bash
set -euxo pipefail

ENV_FILE="env.json"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found"
    exit 1
fi

# Render mustache templates from shared and variant extra trees into the image.
# Uses process substitution (<()) so set -e propagates failures correctly.
for extra_dir in mkosi.extra taiko-tdx-prover/mkosi.extra; do
    [ -d "$extra_dir" ] || continue
    while IFS= read -r -d '' template; do
        rel="${template#$extra_dir/}"
        output_path="$BUILDROOT/${rel%.mustache}"
        mkdir -p "$(dirname "$output_path")"
        mustache "$ENV_FILE" "$template" > "$output_path"
        chmod 644 "$output_path"
        rm -f "$BUILDROOT/$rel"
    done < <(find "$extra_dir" -type f -name '*.mustache' -print0 2>/dev/null)
done

# Upstream tdxs supports only 'azure', 'tdx', 'simulator'. We additionally accept
# 'gcp' in env.json for clarity (GCP CVMs expose raw /dev/tdx_guest, so the wire
# behavior is identical to bare-metal tdx). Translate it on the way out.
TDXS_CONFIG="$BUILDROOT/etc/tdxs/config.yaml"
if [ -f "$TDXS_CONFIG" ]; then
    sed -i -E 's/^([[:space:]]*type:[[:space:]]*)gcp[[:space:]]*$/\1tdx/' "$TDXS_CONFIG"
fi

# NOTE: reth-tdx reads all configuration from CLI flags + env vars set by the
# systemd unit (see /etc/systemd/system/reth-tdx.service). No binary patching
# needed.
