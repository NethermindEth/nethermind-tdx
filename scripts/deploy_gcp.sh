#!/usr/bin/env bash
#
# Convenience wrapper around tools/deploy-gcp for launching a nethermind-tdx
# image as an Intel TDX Confidential VM on Google Cloud.
#
# It auto-locates the newest build/<image>_*.tar.gz (produced by
# `make build IMAGE=<image> GCP=true`), checks that gcloud is authenticated,
# and invokes the Go deploy tool with sensible defaults.
#
# Usage:
#   scripts/deploy_gcp.sh \
#     --id <deployment-id> \
#     --project <gcp-project> \
#     --bucket <gcs-bucket> \
#     [--image-prefix taiko-tdx-prover] \
#     [--disk-path build/<image>_<version>.tar.gz] \
#     [--zone us-central1-a] \
#     [--machine-type c3-standard-4] \
#     [--storage-gb 100] \
#     [--allowed-ip <CIDR>]
#
# Everything after `--` is passed straight through to the Go tool, so any flag
# tools/deploy-gcp/main.go accepts also works here.
#
# Prerequisites:
#   - gcloud CLI authenticated:  gcloud auth application-default login
#   - The Compute Engine and Cloud Storage APIs enabled on the project.
#   - A GCS bucket you own (the image tar.gz is staged there, then the GCE
#     image is created from it; the staging object is removed afterwards).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

ID=""
PROJECT=""
BUCKET=""
DISK_PATH=""
IMAGE_PREFIX="taiko-tdx-prover"
ZONE="us-central1-a"
MACHINE_TYPE="c3-standard-4"
STORAGE_GB="100"
ALLOWED_IP="0.0.0.0/0"
PASSTHROUGH=()

usage() {
    sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --id)            ID="$2"; shift 2 ;;
        --project)       PROJECT="$2"; shift 2 ;;
        --bucket)        BUCKET="$2"; shift 2 ;;
        --disk-path)     DISK_PATH="$2"; shift 2 ;;
        --image-prefix)  IMAGE_PREFIX="$2"; shift 2 ;;
        --zone)          ZONE="$2"; shift 2 ;;
        --machine-type)  MACHINE_TYPE="$2"; shift 2 ;;
        --storage-gb)    STORAGE_GB="$2"; shift 2 ;;
        --allowed-ip)    ALLOWED_IP="$2"; shift 2 ;;
        -h|--help)       usage 0 ;;
        --)              shift; PASSTHROUGH+=("$@"); break ;;
        *)               echo "Unknown flag: $1" >&2; usage 2 ;;
    esac
done

if [ -z "$ID" ] || [ -z "$PROJECT" ] || [ -z "$BUCKET" ]; then
    echo "Error: --id, --project and --bucket are required." >&2
    echo >&2
    usage 2
fi

# Locate the disk image if not explicitly given. The GCP postoutput hook writes
# build/<image>_<version>.tar.gz containing disk.raw.
if [ -z "$DISK_PATH" ]; then
    DISK_PATH="$(ls -t "build/${IMAGE_PREFIX}"*_*.tar.gz 2>/dev/null | head -1 || true)"
    if [ -z "$DISK_PATH" ]; then
        echo "Error: no build/${IMAGE_PREFIX}*_*.tar.gz found." >&2
        echo "Build one first:" >&2
        echo "    make build IMAGE=${IMAGE_PREFIX} GCP=true" >&2
        echo "or pass an explicit --disk-path." >&2
        exit 1
    fi
    echo "Using disk image: $DISK_PATH"
fi
if [ ! -f "$DISK_PATH" ]; then
    echo "Error: disk image not found: $DISK_PATH" >&2
    exit 1
fi

# Sanity-check gcloud / ADC so the deploy fails fast with a clear message
# instead of a deep SDK error.
if ! command -v gcloud >/dev/null 2>&1; then
    echo "Warning: gcloud CLI not found on PATH. The Go tool uses Application" >&2
    echo "Default Credentials; make sure they're configured:" >&2
    echo "    gcloud auth application-default login" >&2
fi

echo
echo "🚀 Deploying '$ID' to project '$PROJECT' (zone $ZONE, $MACHINE_TYPE)..."
echo

exec go run ./tools/deploy-gcp deploy \
    --id "$ID" \
    --project "$PROJECT" \
    --bucket "$BUCKET" \
    --disk-path "$DISK_PATH" \
    --zone "$ZONE" \
    --machine-type "$MACHINE_TYPE" \
    --storage-gb "$STORAGE_GB" \
    --allowed-ip "$ALLOWED_IP" \
    "${PASSTHROUGH[@]}"
