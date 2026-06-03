#!/bin/sh
# GCP-specific network setup. Replaces the hardcoded eth0 approach with
# dynamic interface detection and a wait loop to handle the race between
# NIC probe and early-boot service start (DefaultDependencies=no).

ip link set lo up

# Log all interfaces visible at start (helps debug naming on unknown platforms).
echo "network-setup: interfaces at start: $(ip -o link show | awk -F': ' '/^[0-9]+:/{print $2}' | tr '\n' ' ')"

# Wait up to 60s for any non-loopback interface to appear.
for i in $(seq 60); do
    IFACE=$(ip -o link show | awk -F': ' '/^[0-9]+:/ && $2 != "lo" {print $2; exit}')
    [ -n "$IFACE" ] && break
    echo "network-setup: waiting for interface (attempt $i)..."
    sleep 1
done

if [ -z "$IFACE" ]; then
    echo "network-setup: no non-loopback interface found after 60s" >&2
    exit 1
fi

echo "network-setup: using interface $IFACE"
ip link set "$IFACE" up
chattr +i /etc/resolv.conf
/usr/sbin/udhcpc -i "$IFACE" -n
