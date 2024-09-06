#!/bin/bash

set -e

# Script to run the resulting Yocto image on the host machine as a VM

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
    "
