#!/usr/bin/env bash
#
# Collect the GCP-specific artifacts that the release workflow uploads to GitHub.
# Run after `make build IMAGE=<image> GCP=true DEV=true` succeeds; produces:
#
#   build/<image_id>_<version>.tar.gz              - already produced by mkosi gcp postoutput
#   build/<image_id>_<version>.measurements.json   - vTPM PCR reference values (measured-boot)
#   build/<image_id>_<version>.gcp_measurements.json - TDX RTMR values (dstack-mr, for future use)
#   build/<image_id>_<version>.SHA256SUMS          - sha256 of the three above
#
# Usage:
#   scripts/collect_gcp_release_artifacts.sh <image_id_prefix>
#
# Example:
#   scripts/collect_gcp_release_artifacts.sh taiko-tdx-prover-dev
#
# When run from CI, prints `targz=`, `measurements=`, `gcp_measurements=`,
# `sums=`, `base=` lines on stdout so they can be captured into $GITHUB_OUTPUT.

set -euo pipefail

PREFIX="${1:-}"
if [ -z "$PREFIX" ]; then
    echo "Usage: $0 <image_id_prefix>" >&2
    echo "  e.g. $0 taiko-tdx-prover-dev" >&2
    exit 2
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# Newest matching tar.gz and EFI from a GCP build.
TARGZ="$(ls -t "build/${PREFIX}"_*.tar.gz 2>/dev/null | head -1 || true)"
EFI="$(ls -t "build/${PREFIX}"_*.efi 2>/dev/null | head -1 || true)"

if [ -z "$TARGZ" ] || [ ! -f "$TARGZ" ]; then
    echo "Error: no build/${PREFIX}_*.tar.gz found. Run 'make build IMAGE=... GCP=true' first." >&2
    exit 1
fi
if [ -z "$EFI" ] || [ ! -f "$EFI" ]; then
    echo "Error: no build/${PREFIX}_*.efi found. Did the build complete?" >&2
    exit 1
fi

BASE="$(basename "$TARGZ" .tar.gz)"
EFI_BASE="$(basename "$EFI" .efi)"
if [ "$BASE" != "$EFI_BASE" ]; then
    echo "Error: tar.gz ($BASE) and EFI ($EFI_BASE) belong to different builds." >&2
    echo "       Clean build/ and re-run to avoid mixing artifacts." >&2
    exit 1
fi

MEASUREMENTS="build/${BASE}.measurements.json"
GCP_MEASUREMENTS="build/${BASE}.gcp_measurements.json"
SUMS="build/${BASE}.SHA256SUMS"

# vTPM PCR measurements (same tool and format as Azure). These are what raiko2
# register-tdx --release-url uses to cross-check a live VM's quote. They work
# on GCP because the VM is created with vTPM enabled (ShieldedInstanceConfig).
echo "Generating vTPM PCR measurements (measured-boot)..." >&2
make measure "FILE=$EFI" >&2
mv build/measurements.json "$MEASUREMENTS"

# Augment with registration metadata (same as Azure collect script).
python3 - "$MEASUREMENTS" "$BASE" <<'EOF'
import json, sys

mfile, base = sys.argv[1], sys.argv[2]
m = json.load(open(mfile))

m["registration"] = {
    "image": base,
    "pcr_bitmap": "0xBA10",
    "pcrs_covered": [4, 9, 11, 12, 13, 15],
    "platform": "gcp",
}

json.dump(m, open(mfile, "w"), indent=2)
print(f"Augmented {mfile} with registration block", file=__import__('sys').stderr)
EOF

# TDX RTMR measurements (dstack-mr). These are TDX-native measurements and
# are NOT used by raiko2 today (which uses vTPM PCRs via AzureTdxVerifier).
# Included for future use with a TDX-native on-chain verifier.
echo "Generating TDX RTMR measurements (dstack-mr)..." >&2
make measure-gcp "FILE=$EFI" >&2
mv build/gcp_measurements.json "$GCP_MEASUREMENTS"

# Checksums.
(
    cd build
    sha256sum "${BASE}.tar.gz" "${BASE}.measurements.json" "${BASE}.gcp_measurements.json" > "${BASE}.SHA256SUMS"
)

echo "targz=$TARGZ"
echo "measurements=$MEASUREMENTS"
echo "gcp_measurements=$GCP_MEASUREMENTS"
echo "sums=$SUMS"
echo "base=$BASE"
