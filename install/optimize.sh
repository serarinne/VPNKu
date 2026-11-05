#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERR] This script must be run as root" 1>&2
    exit 1
fi

SYSCTL_CONFIG="/etc/sysctl.conf"

echo "[INFO] Starting BBR & TCP optimization..."

set_sysctl_config() {
    local key="$1"
    local value="$2"
    sed -i "/^${key}/d" "$SYSCTL_CONFIG"
    echo "${key}=${value}" >> "$SYSCTL_CONFIG"
}

modprobe tcp_bbr

set_sysctl_config "net.core.default_qdisc" "fq"
set_sysctl_config "net.ipv4.tcp_congestion_control" "bbr"
set_sysctl_config "fs.file-max" "51200"
set_sysctl_config "net.core.rmem_max" "67108864"
set_sysctl_config "net.core.wmem_max" "67108864"
set_sysctl_config "net.core.netdev_max_backlog" "250000"
set_sysctl_config "net.core.somaxconn" "4096"
set_sysctl_config "net.ipv4.tcp_syncookies" "1"
set_sysctl_config "net.ipv4.tcp_tw_reuse" "1"
set_sysctl_config "net.ipv4.tcp_fin_timeout" "30"
set_sysctl_config "net.ipv4.tcp_keepalive_time" "1200"
set_sysctl_config "net.ipv4.ip_local_port_range" "10000 65000"
set_sysctl_config "net.ipv4.tcp_max_syn_backlog" "8192"

sysctl -p >/dev/null 2>&1

echo "[OK] BBR & TCP optimization complete!"
echo ""
echo "[INFO] Starting firewall configuration..."

apt-get install -y iptables-persistent >/dev/null 2>&1

iptables -F OUTPUT
iptables -A OUTPUT -m string --string "get_peers" --algo bm -j DROP
iptables -A OUTPUT -m string --string "announce_peer" --algo bm -j DROP
iptables -A OUTPUT -m string --string "find_node" --algo bm -j DROP
iptables -A OUTPUT -m string --algo bm --string "BitTorrent" -j DROP
iptables -A OUTPUT -m string --algo bm --string "torrent" -j DROP
iptables -A OUTPUT -m string --algo bm --string "info_hash" -j DROP

iptables-save > /etc/iptables/rules.v4

echo "[OK] Firewall configuration complete!"
echo "NOTE: ddos-deflate is not installed (obsolete). Use Fail2Ban instead."