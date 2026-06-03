#!/bin/sh
# GCP-specific network setup. Uses sysfs to find the physical NIC (only
# real hardware interfaces have /sys/class/net/<iface>/device), avoiding
# virtual interfaces like sit0, ip6tnl0, etc.

ip link set lo up

# Wait up to 60s for a physical (non-virtual, non-loopback) interface.
for i in $(seq 60); do
    IFACE=""
    for path in /sys/class/net/*; do
        name=$(basename "$path")
        [ "$name" = "lo" ] && continue
        [ -e "$path/device" ] || continue   # skip virtual interfaces
        IFACE="$name"
        break
    done
    [ -n "$IFACE" ] && break
    echo "network-setup: waiting for physical interface (attempt $i)..." >/dev/kmsg
    sleep 1
done

if [ -z "$IFACE" ]; then
    echo "network-setup: no physical interface found after 60s" >/dev/kmsg
    exit 1
fi

echo "network-setup: using interface $IFACE" >/dev/kmsg
ip link set "$IFACE" up
chattr +i /etc/resolv.conf
/usr/sbin/udhcpc -i "$IFACE" -n
