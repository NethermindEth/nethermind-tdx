#!/bin/sh

source /etc/json-config.conf

if [ -f /etc/json_config.json ]; then
    eval "$(/bin/sh /usr/bin/json_config_parse.sh /etc/json_config.json "${ALLOWED_KEYS}")"
else
    echo "Warning: /etc/json_config.json not found. Environment variables not set." >&2
fi
