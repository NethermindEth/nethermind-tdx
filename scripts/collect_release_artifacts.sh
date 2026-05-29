#!/usr/bin/env bash
#
# Collect the artifacts that the release workflow uploads to GitHub. Run after
# `make build IMAGE=<image> AZURE=true DEV=true` succeeds; produces:
#
#   build/<image_id>_<version>.vhd                  - already produced by mkosi
#   build/<image_id>_<version>.measurements.json    - measured-boot output
#   build/<image_id>_<version>.SHA256SUMS           - sha256 of the two above
#
# Usage:
#   scripts/collect_release_artifacts.sh <image_id_prefix>
#
# Example:
#   scripts/collect_release_artifacts.sh taiko-tdx-prover-dev
#
# When run from CI, prints `vhd=`, `measurements=`, `sums=`, `base=` lines on
# stdout so they can be captured into $GITHUB_OUTPUT.

set -euo pipefail

PREFIX="${1:-}"
if [ -z "$PREFIX" ]; then
    echo "Usage: $0 <image_id_prefix>" >&2
    echo "  e.g. $0 taiko-tdx-prover-dev" >&2
    exit 2
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# Newest matching VHD and EFI. `ls -t` orders by mtime; the postoutput hook
# writes the VHD after the EFI, so they share a build run when picked together.
VHD="$(ls -t "build/${PREFIX}"_*.vhd 2>/dev/null | head -1 || true)"
EFI="$(ls -t "build/${PREFIX}"_*.efi 2>/dev/null | head -1 || true)"

if [ -z "$VHD" ] || [ ! -f "$VHD" ]; then
    echo "Error: no build/${PREFIX}_*.vhd found. Run 'make build IMAGE=... AZURE=true' first." >&2
    exit 1
fi
if [ -z "$EFI" ] || [ ! -f "$EFI" ]; then
    echo "Error: no build/${PREFIX}_*.efi found. Did the build complete?" >&2
    exit 1
fi

BASE="$(basename "$VHD" .vhd)"
EFI_BASE="$(basename "$EFI" .efi)"
if [ "$BASE" != "$EFI_BASE" ]; then
    echo "Error: VHD ($BASE) and EFI ($EFI_BASE) belong to different builds." >&2
    echo "       Clean build/ and re-run to avoid mixing artifacts." >&2
    exit 1
fi

MEASUREMENTS="build/${BASE}.measurements.json"
SUMS="build/${BASE}.SHA256SUMS"

# `make measure` runs measured-boot through env_wrapper.sh and writes
# build/measurements.json. Rename to the per-image filename afterwards so
# we don't clobber previous runs.
make measure "FILE=$EFI"
mv build/measurements.json "$MEASUREMENTS"

# Augment the measurements file with image-side registration metadata so
# `xtask register-tdx --release-url ...` has everything it needs to
# cross-check a live VM's quote without any other lookup. Operator-supplied
# values (verifier address, L1 RPC, signer key) stay out of the release.
python3 - "$MEASUREMENTS" "$BASE" <<'EOF'
import json, sys

mfile, base = sys.argv[1], sys.argv[2]
m = json.load(open(mfile))

# PCR bitmap used by xtask register-tdx (PCRs 4, 9, 11, 12, 13, 15 = 0xBA10).
# Captured here so the registration script doesn't have to guess.
m["registration"] = {
    "image": base,
    "pcr_bitmap": "0xBA10",
    "pcrs_covered": [4, 9, 11, 12, 13, 15],
}

json.dump(m, open(mfile, "w"), indent=2)
print(f"Augmented {mfile} with registration block")
EOF

# Use the directory-relative form so the SHA256SUMS file is portable.
(
    cd build
    sha256sum "${BASE}.vhd" "${BASE}.measurements.json" > "${BASE}.SHA256SUMS"
)

echo "vhd=$VHD"
echo "measurements=$MEASUREMENTS"
echo "sums=$SUMS"
echo "base=$BASE"
