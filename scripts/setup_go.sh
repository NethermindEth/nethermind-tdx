#!/bin/bash

# Go setup script

set -e

GO_VERSION=1.23.1

TAR_FILE=go${GO_VERSION}.linux-amd64.tar.gz
TARGET_DIR=/usr/local

curl -OL https://go.dev/dl/${TAR_FILE}
sudo rm -rf ${TARGET_DIR}/go && sudo tar -C ${TARGET_DIR} -xzf ${TAR_FILE}
rm ${TAR_FILE}

if ! grep -q "export PATH=\$PATH:${TARGET_DIR}/go/bin" ~/.profile; then
    echo "" >> ~/.profile
    echo "export PATH=\$PATH:${TARGET_DIR}/go/bin" >> ~/.profile
fi

source ~/.profile

if ! go version; then
    echo "Failed to install Go ${GO_VERSION}"
    exit 1
fi

echo "Go ${GO_VERSION} installed"
