#!/bin/bash
set -euxo pipefail

ENV_FILE="env.json"
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found"
    exit 1
fi

# Render mustache templates from shared and variant extra trees into the image.
# Uses process substitution (<()) so set -e propagates failures correctly.
for extra_dir in mkosi.extra surge-tdx-prover/mkosi.extra; do
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

# Derive the tdxs attestation issuer from the build profile (see
# taiko-tdx-prover/render-config.sh for rationale): azure -> azure, else -> tdx.
TDXS_CONFIG="$BUILDROOT/etc/tdxs/config.yaml"
if [ -f "$TDXS_CONFIG" ]; then
    if [[ "${PROFILES:-}" == *"azure"* ]]; then
        TDXS_ISSUER="azure"
    else
        TDXS_ISSUER="tdx"
    fi
    sed -i -E "s/^([[:space:]]*type:[[:space:]]*)__TDXS_ISSUER__[[:space:]]*$/\1${TDXS_ISSUER}/" "$TDXS_CONFIG"
fi

# TODO: remove this once not necessary anymore
# L1_CONTRACT=$(jq -r '.tdx_prover.l1_contract' "$ENV_FILE")
# L2_CONTRACT=$(jq -r '.tdx_prover.l2_contract' "$ENV_FILE")
# grep -q "0xa3c616dd54F6BB35a736cD6968c8EF7176faCACc" "$BUILDROOT/usr/bin/raiko" || { echo "Error: Expected default L1 contract address not found"; exit 1; }
# grep -q "0x7633740000000000000000000000000000010001" "$BUILDROOT/usr/bin/raiko" || { echo "Error: Expected default L2 contract address not found"; exit 1; }
# sed -i "s/0xa3c616dd54F6BB35a736cD6968c8EF7176faCACc/$L1_CONTRACT/g" "$BUILDROOT/usr/bin/raiko"
# sed -i "s/0x7633740000000000000000000000000000010001/$L2_CONTRACT/g" "$BUILDROOT/usr/bin/raiko"
