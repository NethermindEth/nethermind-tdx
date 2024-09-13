#!/bin/sh

JSON_FILE="$1"
ALLOWED_KEYS="$2"

if [ ! -f "$JSON_FILE" ]; then
    echo "Error: File not found: $JSON_FILE" >&2
    exit 1
fi

if [ -z "$ALLOWED_KEYS" ]; then
    echo "Error: ALLOWED_KEYS environment variable is not set." >&2
    exit 1
fi

for key in $ALLOWED_KEYS; do
    value=$(jq -r --arg k "$key" '.[$k] | @sh' "$JSON_FILE")
    echo "export $key=$value"
done
