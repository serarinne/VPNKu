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

modprobe tcp_bbr 2>/dev/null || true

set_sysctl_config "net.core.default_qdisc" "fq"
set_sysctl_config "net.ipv4.tcp_congestion_control" "bbr"
set_sysctl_config "fs.file-max" "1048576"
set_sysctl_config "net.core.rmem_max" "67108864"
set_sysctl_config "net.core.wmem_max" "67108864"
set_sysctl_config "net.core.netdev_max_backlog" "250000"
set_sysctl_config "net.core.somaxconn" "65535"
set_sysctl_config "net.ipv4.tcp_syncookies" "1"
set_sysctl_config "net.ipv4.tcp_tw_reuse" "1"
set_sysctl_config "net.ipv4.tcp_fin_timeout" "15"
set_sysctl_config "net.ipv4.tcp_keepalive_time" "600"
set_sysctl_config "net.ipv4.ip_local_port_range" "10000 65000"
set_sysctl_config "net.ipv4.tcp_max_syn_backlog" "16384"
set_sysctl_config "net.ipv4.tcp_fastopen" "3"
set_sysctl_config "net.ipv4.tcp_mtu_probing" "1"
set_sysctl_config "net.ipv4.tcp_slow_start_after_idle" "0"
set_sysctl_config "net.ipv4.tcp_notsent_lowat" "16384"
set_sysctl_config "vm.swappiness" "10"
set_sysctl_config "vm.dirty_ratio" "15"
set_sysctl_config "vm.dirty_background_ratio" "5"

sysctl -p >/dev/null 2>&1

echo "[OK] BBR & TCP optimization complete!"
echo ""
echo "[INFO] Starting firewall configuration..."

DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null 2>&1

iptables -F OUTPUT 2>/dev/null || true
iptables -A OUTPUT -m string --string "get_peers" --algo bm -j DROP 2>/dev/null || true
iptables -A OUTPUT -m string --string "announce_peer" --algo bm -j DROP 2>/dev/null || true
iptables -A OUTPUT -m string --string "find_node" --algo bm -j DROP 2>/dev/null || true
iptables -A OUTPUT -m string --algo bm --string "BitTorrent" -j DROP 2>/dev/null || true
iptables -A OUTPUT -m string --algo bm --string "torrent" -j DROP 2>/dev/null || true
iptables -A OUTPUT -m string --algo bm --string "info_hash" -j DROP 2>/dev/null || true

iptables-save > /etc/iptables/rules.v4 2>/dev/null || true

echo "[OK] Firewall configuration complete!"

echo ""
echo "[INFO] Raising file descriptor limits..."
cat > /etc/security/limits.d/99-vpnku.conf <<'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF

echo "[INFO] Creating systemd drop-ins for xray & haproxy..."
mkdir -p /etc/systemd/system/xray.service.d /etc/systemd/system/haproxy.service.d
cat > /etc/systemd/system/xray.service.d/override.conf <<'EOF'
[Service]
LimitNOFILE=1048576
Nice=-5
EOF
cat > /etc/systemd/system/haproxy.service.d/override.conf <<'EOF'
[Service]
LimitNOFILE=1048576
Nice=-5
EOF
systemctl daemon-reload

echo "[INFO] Creating swap if not present..."
if ! swapon --show | grep -q .; then
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null
    fi
    swapon /swapfile
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    echo "[OK] Swap 2GB created and enabled."
else
    echo "[INFO] Swap already present, skipping."
fi

echo "[OK] Optimization complete!"
echo "NOTE: ddos-deflate is not installed (obsolete). Use Fail2Ban instead."