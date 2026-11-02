#!/usr/bin/env bash
set -euo pipefail

kernel="${1:?Usage: smoke-boot.sh <bzImage> <expected-version>}"
version="${2:?Expected kernel version is required}"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/root/bin" "$work/root/dev" "$work/root/proc"
cp /usr/bin/busybox "$work/root/bin/busybox"
ln -s busybox "$work/root/bin/sh"
cat > "$work/root/init" <<'INIT'
#!/bin/sh
/bin/busybox mount -t proc proc /proc
/bin/busybox mount -t devtmpfs devtmpfs /dev
exec </dev/console >/dev/console 2>&1
printf 'KERNEL_BOOT_OK=%s\n' "$(/bin/busybox uname -r)"
/bin/busybox poweroff -f
INIT
chmod +x "$work/root/init"
(cd "$work/root" && find . -print0 | cpio --null -o --format=newc --quiet) | gzip > "$work/initramfs.gz"
timeout 180 qemu-system-x86_64 -machine q35 -accel tcg -m 512 -smp 2 \
    -nographic -no-reboot -nic none \
    -kernel "$kernel" -initrd "$work/initramfs.gz" \
    -append 'console=ttyS0 rdinit=/init panic=1' > "$work/boot.log" 2>&1 || {
    cat "$work/boot.log"
    exit 1
}
cat "$work/boot.log"
grep -Fx "KERNEL_BOOT_OK=$version" <(tr -d '\r' < "$work/boot.log")
