#!/bin/sh
# GCP-specific network setup. Replaces the hardcoded eth0 approach with
# dynamic interface detection and a wait loop to handle the race between
# NIC probe and early-boot service start (DefaultDependencies=no).

ip link set lo up

# Wait up to 60s for any ethernet-style interface to appear.
for i in $(seq 60); do
    IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+: e[a-z]/{print $2; exit}')
    [ -n "$IFACE" ] && break
    sleep 1
done

if [ -z "$IFACE" ]; then
    echo "network-setup: no ethernet interface found after 60s" >&2
    exit 1
fi

echo "network-setup: using interface $IFACE"
ip link set "$IFACE" up
chattr +i /etc/resolv.conf
/usr/sbin/udhcpc -i "$IFACE" -n
