#!/bin/bash

set -euo pipefail

if [ $# -ne 2 ]; then
    echo "Usage: $0 <path_to_project> <path_to_publish_args_file>"
    exit 1
fi

PROJECT_PATH="$1"
PUBLISH_ARGS_FILE="$2"

if [ ! -f "$PUBLISH_ARGS_FILE" ]; then
    echo "Publish arguments file not found: $PUBLISH_ARGS_FILE"
    exit 1
fi

PUBLISH_ARGS=$(cat "$PUBLISH_ARGS_FILE")

build_and_hash() {
    local build_dir="$1"
    
    # Clean and publish the project
    dotnet clean "$PROJECT_PATH" --output "$build_dir"
    dotnet publish "$PROJECT_PATH" $PUBLISH_ARGS --output "$build_dir"
    
    # Calculate hash of the output directory
    find "$build_dir" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}'
}

# Perform two builds
BUILD_DIR_1=$(mktemp -d)
BUILD_DIR_2=$(mktemp -d)

echo "Performing first build..."
HASH_1=$(build_and_hash "$BUILD_DIR_1")

echo "Performing second build..."
HASH_2=$(build_and_hash "$BUILD_DIR_2")

# Compare the hashes
if [ "$HASH_1" == "$HASH_2" ]; then
    echo "The build is reproducible!"
else
    echo "The build is not reproducible."
    echo "Hash 1: $HASH_1"
    echo "Hash 2: $HASH_2"
    
    # Optional: Show diff of the build directories
    echo "Differences between builds:"
    diff -r "$BUILD_DIR_1" "$BUILD_DIR_2" || true
fi

# Clean up temporary directories
rm -rf "$BUILD_DIR_1" "$BUILD_DIR_2"