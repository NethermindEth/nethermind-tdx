#!/usr/bin/env bash
# Remove build-host cache leakage from the image tree.
#
# Why: on Apple-Silicon hosts the image is built under Lima with Rosetta
# emulating the x86_64 toolchain. Every x86 binary mkosi-chroot runs during
# the postinst phase (groupadd, useradd, systemctl, ...) makes Rosetta drop
# its AOT translation cache into the buildroot at /.cache/rosetta. A native
# x86_64 host (e.g. GitHub's ubuntu-24.04 runner) never creates it. The same
# source tree then yields a different cpio, a different initrd, and different
# PCR/RTMR measurements — breaking reproducible TDX measurements.
#
# A root-level /.cache has no place in this minimal image regardless of host,
# so removing it is safe and is a no-op on hosts that never created it.
#
# This must run in the finalize phase: the leak is produced by the chroot
# calls in the postinst, so cleaning it any earlier would just let the next
# chroot recreate it.
set -euxo pipefail

rm -rf "$BUILDROOT/.cache"
