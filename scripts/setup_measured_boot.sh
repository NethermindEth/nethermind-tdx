#!/bin/bash

# Setup script for measured-boot

set -e

if [ ! -d "measured-boot" ]; then
    git clone https://github.com/flashbots/measured-boot
fi

go build -C measured-boot -o measured-boot
