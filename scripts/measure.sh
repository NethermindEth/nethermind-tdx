#!/bin/bash

# Measure script
# Can be used in either docker or local mode

set -e

if [ -z "$DOCKER_BUILD" ]; then
    echo "Measuring locally"

    MEASURED_BOOT=$(realpath measured-boot/measured-boot)
    IMAGE_PATH=$(realpath "$ARTIFACTS_DIR/cvm-image-azure-tdx.rootfs.wic.vhd")
    OUTPUT_PATH=$(realpath "$ARTIFACTS_DIR/measurements.json")

    cd "./$BUILD_DIR"
else
    echo "Measuring in docker container"

    MEASURED_BOOT=/usr/bin/measured-boot
    IMAGE_PATH="/$ARTIFACTS_DIR/cvm-image-azure-tdx.rootfs.wic.vhd"
    OUTPUT_PATH="/$ARTIFACTS_DIR/measurements.json"

    cd "/$BUILD_DIR"
fi

cd srcs/poky
source oe-init-build-env

$MEASURED_BOOT $IMAGE_PATH $OUTPUT_PATH

echo "Measured boot output saved to $OUTPUT_PATH"
