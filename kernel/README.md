# Kernel updates

`version` pins the default kernel used by `mkosi.build`. Linux 6.18 is a
maintained LTS branch. Version 6.18.60 includes the IPv4 options lifetime fix
for [CVE-2026-98432](https://security-tracker.debian.org/tracker/CVE-2026-98432).

`patches/0001-tcp-fix-request-socket-timer-uaf.patch` backports upstream
[97c8a3c1f73d](https://github.com/torvalds/linux/commit/97c8a3c1f73d828de43a5a88e8a9a143efb2b661),
a separate request-socket timer fix that is not present in upstream 6.18.60.
Remove the backport when the selected release contains it. Patch contents
are part of the compiled-kernel cache key.

The kernel workflow builds the repository configuration and boots it under
QEMU. This checks a normal x86 boot, not TDX attestation. Before deploying a
new kernel, rebuild each used image/profile, regenerate its measured-boot
reference values and verify boot and attestation on TDX hardware. Existing
images and their measurements are not updated by merging this change.

`KERNEL_VERSION` remains an explicit build override. Custom versions need
the same security and platform validation as the default.
