#!/bin/bash

set -e

# Script to setup swtpm on ubuntu

sudo apt install swtpm swtpm-tools -y

mkdir /tmp/tdxqemu-tpm || true
swtpm_setup --tpmstate /tmp/tdxqemu-tpm \
  --create-ek-cert \
  --create-platform-cert \
  --create-spk \
  --tpm2 \
  --overwrite
swtpm socket --tpmstate dir=/tmp/tdxqemu-tpm \
  --ctrl type=unixio,path=/tmp/tdxqemu-tpm/swtpm-sock \
  --tpm2 \
  --log level=20
