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

# The tdxs attestation issuer is derived from the BUILD PROFILE, not env.json:
#   azure profile            -> "azure" (Azure vTPM-bound TDX quote)
#   gcp profile / bare-metal -> "tdx"   (native DCAP quote via /dev/tdx_guest;
#                                        GCP CVMs expose it directly)
# This keeps the issuer in lockstep with `make build AZURE=true|GCP=true`, so
# there is no separate `tdxs_issuer` knob in env.json to keep in sync. The
# template emits the sentinel __TDXS_ISSUER__ which we replace here.
TDXS_CONFIG="$BUILDROOT/etc/tdxs/config.yaml"
if [ -f "$TDXS_CONFIG" ]; then
    if [[ "${PROFILES:-}" == *"azure"* ]]; then
        TDXS_ISSUER="azure"
    else
        TDXS_ISSUER="tdx"
    fi
    sed -i -E "s/^([[:space:]]*type:[[:space:]]*)__TDXS_ISSUER__[[:space:]]*$/\1${TDXS_ISSUER}/" "$TDXS_CONFIG"
    echo "render-config: tdxs issuer set to '${TDXS_ISSUER}' (profiles: ${PROFILES:-none})"
fi

# NOTE: reth-tdx reads all configuration from CLI flags + env vars set by the
# systemd unit (see /etc/systemd/system/reth-tdx.service). No binary patching
# needed.
