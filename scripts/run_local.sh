#!/bin/bash

set -e

# Script to run the resulting Yocto image on the host machine as a VM

if [ -z "$DISK_SIZE" ]; then
    echo "DISK_SIZE is not set"
    exit 1
fi

if [ -z "$PERSISTENT_DISK" ]; then
    echo "PERSISTENT_DISK is not set"
    exit 1
else
    PERSISTENT_DISK=$(realpath "$PERSISTENT_DISK")
fi

if ! command -v qemu-img &> /dev/null; then
    sudo apt install -y qemu-utils
fi

if [ ! -f "$PERSISTENT_DISK" ]; then
    echo "Persistent disk image not found"
    read -r -p "Are you sure you want to create a $DISK_SIZE persistent disk image? [y/N] " response
    response=${response,,}

    if [[ "$response" =~ ^(yes|y)$ ]]; then
        qemu-img create -f qcow2 "$PERSISTENT_DISK" "$DISK_SIZE"
    else
        echo "Persistent disk image not created. Exiting."
        exit 1
    fi
fi

cd build/srcs/poky
source oe-init-build-env

ln -s "$PWD/tmp/work/x86_64-linux/qemu-helper-native/1.0/recipe-sysroot-native/usr/bin/qemu-system-x86_64" \
    "$PWD/tmp/work/x86_64-linux/qemu-helper-native/1.0/recipe-sysroot-native/usr/bin/tdx" ||
    true

runqemu cvm-image-azure \
    wic \
    nographic \
    kvm \
    ovmf \
    qemuparams=" \
      -m 8G, \
      -net nic,model=virtio \
      -net user \
      -chardev socket,id=chrtpm,path=/tmp/tdxqemu-tpm/swtpm-sock \
      -tpmdev emulator,id=tpm0,chardev=chrtpm \
      -device tpm-tis,tpmdev=tpm0 \
      -hdb "$PERSISTENT_DISK" \
    "
