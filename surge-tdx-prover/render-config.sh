#!/bin/bash
set -euxo pipefail

ENV_FILE="env.json"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: env.json not found"
    exit 1
fi

# Find and process all mustache templates in mkosi.extra directory
find surge-tdx-prover/mkosi.extra -type f -name "*.mustache" | while read -r template; do
    rel_path="${template#surge-tdx-prover/mkosi.extra/}"
    output_path="$BUILDROOT/${rel_path%.mustache}"

    mustache "$ENV_FILE" "$template" > "$output_path"
    chmod 644 "$output_path"

    rm "$BUILDROOT/$rel_path"
done

# TODO: remove this once not necessary anymore
# L1_CONTRACT=$(jq -r '.raiko.l1_contract' "$ENV_FILE")
# L2_CONTRACT=$(jq -r '.raiko.l2_contract' "$ENV_FILE")
# grep -q "0xa3c616dd54F6BB35a736cD6968c8EF7176faCACc" "$BUILDROOT/usr/bin/raiko" || { echo "Error: Expected default L1 contract address not found"; exit 1; }
# grep -q "0x7633740000000000000000000000000000010001" "$BUILDROOT/usr/bin/raiko" || { echo "Error: Expected default L2 contract address not found"; exit 1; }
# sed -i "s/0xa3c616dd54F6BB35a736cD6968c8EF7176faCACc/$L1_CONTRACT/g" "$BUILDROOT/usr/bin/raiko"
# sed -i "s/0x7633740000000000000000000000000000010001/$L2_CONTRACT/g" "$BUILDROOT/usr/bin/raiko"
