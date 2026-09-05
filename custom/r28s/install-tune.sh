#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "This installer must be run as root." >&2
    exit 1
fi

if ! command -v ethtool >/dev/null 2>&1; then
    if command -v apk >/dev/null 2>&1; then
        apk add ethtool
    elif command -v opkg >/dev/null 2>&1; then
        opkg install ethtool
    else
        echo "Warning: ethtool is not available and no supported package manager was found." >&2
    fi
fi

cat > /usr/sbin/r28s-tune <<'EOF'
#!/bin/sh

[ -w /proc/irq/48/smp_affinity_list ] && echo 1 > /proc/irq/48/smp_affinity_list

[ -w /sys/class/net/eth0/queues/rx-0/rps_cpus ] && echo d > /sys/class/net/eth0/queues/rx-0/rps_cpus
[ -w /sys/class/net/eth1/queues/rx-0/rps_cpus ] && echo e > /sys/class/net/eth1/queues/rx-0/rps_cpus

[ -w /sys/class/net/eth0/queues/rx-0/rps_flow_cnt ] && echo 0 > /sys/class/net/eth0/queues/rx-0/rps_flow_cnt
[ -w /sys/class/net/eth1/queues/rx-0/rps_flow_cnt ] && echo 0 > /sys/class/net/eth1/queues/rx-0/rps_flow_cnt
sysctl -w net.core.rps_sock_flow_entries=0 >/dev/null 2>&1 || true

if command -v ethtool >/dev/null 2>&1; then
    ethtool -K eth1 sg on tso on gso on >/dev/null 2>&1 || true
fi

if command -v modprobe >/dev/null 2>&1 && modprobe tcp_bbr >/dev/null 2>&1; then
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true
fi
EOF

cat > /etc/init.d/r28s-tune <<'EOF'
#!/bin/sh /etc/rc.common

START=99

start() {
    /usr/sbin/r28s-tune
}
EOF

mkdir -p /etc/hotplug.d/iface
cat > /etc/hotplug.d/iface/99-r28s-tune <<'EOF'
#!/bin/sh

[ "$ACTION" = "ifup" ] && /usr/sbin/r28s-tune
EOF

chmod 0755 \
    /usr/sbin/r28s-tune \
    /etc/init.d/r28s-tune \
    /etc/hotplug.d/iface/99-r28s-tune

if uci -q get network.@globals[0] >/dev/null 2>&1; then
    uci -q set network.@globals[0].packet_steering='0'
    uci -q commit network
fi

if [ -x /etc/init.d/packet_steering ]; then
    /etc/init.d/packet_steering stop >/dev/null 2>&1 || true
    /etc/init.d/packet_steering disable >/dev/null 2>&1 || true
fi

rm -f /etc/modules.d/90-bbr /etc/sysctl.d/90-bbr.conf

/etc/init.d/r28s-tune enable >/dev/null 2>&1 || true
/usr/sbin/r28s-tune

echo "R28S tuning installed and applied."
