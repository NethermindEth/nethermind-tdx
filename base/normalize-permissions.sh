#!/usr/bin/env bash
# Strip group-write and other-write bits across the whole image tree.
#
# Why: mkosi copies files from mkosi.extra/ into the rootfs preserving the
# host's permissions. A host with umask 002 (e.g. the Azure devnet box)
# produces 664/775 file modes; a host with umask 022 (e.g. GitHub-hosted
# ubuntu-24.04) produces 644/755. The same source then yields different
# cpio metadata, different initrd bytes, and different PCR[4]/PCR[9]/PCR[11]
# — breaking reproducible TDX measurements.
#
# `chmod g-w,o-w` only removes group/other write bits. It leaves owner
# permissions, read/execute bits, and suid/sgid alone. Safe to apply
# across the whole tree.
set -euxo pipefail

find "$BUILDROOT" -xdev \( -type f -o -type d \) -exec chmod g-w,o-w {} +
