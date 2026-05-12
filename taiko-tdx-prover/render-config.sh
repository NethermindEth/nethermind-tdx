#!/bin/bash
set -euxo pipefail

ENV_FILE="env.json"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found"
    exit 1
fi

# Find and process all mustache templates in mkosi.extra directory
find taiko-tdx-prover/mkosi.extra -type f -name "*.mustache" | while read -r template; do
    rel_path="${template#taiko-tdx-prover/mkosi.extra/}"
    output_path="$BUILDROOT/${rel_path%.mustache}"

    mustache "$ENV_FILE" "$template" > "$output_path"
    chmod 644 "$output_path"

    rm "$BUILDROOT/$rel_path"
done

# NOTE: raiko2 uses TOML config and CLI args for all configuration.
# No binary patching needed.
