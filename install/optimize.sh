#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERR] This script must be run as root" 1>&2
    exit 1
fi

SYSCTL_CONFIG="/etc/sysctl.conf"

echo "[INFO] Starting TCP/network optimization..."

set_sysctl_config() {
    local key="$1"
    local value="$2"
    local key_re
    key_re="$(printf '%s' "$key" | sed 's/[.]/\\./g')"
    # Remove any existing active or commented assignment for this key (avoid duplicates/stale values)
    sed -i -E "/^[[:space:]]*#?[[:space:]]*${key_re}[[:space:]]*=/d" "$SYSCTL_CONFIG"
    echo "${key}=${value}" >> "$SYSCTL_CONFIG"
}

# --- Congestion control: prefer BBR, fall back to cubic if unavailable ---
modprobe tcp_bbr 2>/dev/null || true
if grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
    set_sysctl_config "net.core.default_qdisc" "fq"
    set_sysctl_config "net.ipv4.tcp_congestion_control" "bbr"
    echo "[OK] BBR congestion control enabled (fq qdisc)."
else
    echo "[WARN] BBR not available in this kernel; keeping default congestion control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo unknown)"
    set_sysctl_config "net.core.default_qdisc" "fq_codel"
fi

# --- Buffer & backlog tuning (helps high-BDP / many-connection workloads) ---
set_sysctl_config "fs.file-max" "1048576"
set_sysctl_config "net.core.rmem_default" "262144"
set_sysctl_config "net.core.wmem_default" "262144"
set_sysctl_config "net.core.rmem_max" "67108864"
set_sysctl_config "net.core.wmem_max" "67108864"
set_sysctl_config "net.core.netdev_max_backlog" "250000"
set_sysctl_config "net.core.somaxconn" "65535"
set_sysctl_config "net.ipv4.tcp_rmem" "4096 87380 67108864"
set_sysctl_config "net.ipv4.tcp_wmem" "4096 65536 67108864"

# --- TCP behavior tuning ---
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
set_sysctl_config "net.ipv4.tcp_window_scaling" "1"

# --- Memory/VM tuning (stability, not network speed) ---
set_sysctl_config "vm.swappiness" "10"
set_sysctl_config "vm.dirty_ratio" "15"
set_sysctl_config "vm.dirty_background_ratio" "5"

if sysctl -p >/dev/null 2>&1; then
    echo "[OK] sysctl settings applied."
else
    echo "[WARN] Some sysctl values could not be applied (check kernel support)."
fi

echo ""
echo "[INFO] Skipping iptables string-matching (ineffective on encrypted VPN traffic and adds CPU overhead)."
echo "[INFO] Firewall rules are managed by install.sh."

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
systemctl daemon-reload 2>/dev/null || true

echo "[INFO] Creating swap if not present..."
if ! swapon --show 2>/dev/null | grep -q .; then
    if [ ! -f /swapfile ]; then
        fallocate -l 2G /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
        chmod 600 /swapfile
        mkswap /swapfile >/dev/null
    fi
    swapon /swapfile 2>/dev/null || true
    if ! grep -q '/swapfile' /etc/fstab 2>/dev/null; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    echo "[OK] Swap 2GB created and enabled."
else
    echo "[INFO] Swap already present, skipping."
fi

echo ""
echo "[OK] Optimization complete!"
echo "NOTE: Verify BBR with: sysctl net.ipv4.tcp_congestion_control"