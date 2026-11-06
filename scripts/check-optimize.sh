#!/bin/bash
# Verify optimization settings applied correctly.
set -u

echo "=== VPNKu optimization check ==="
echo "Congestion control : $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo n/a)"
echo "Available CCs      : $(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null || echo n/a)"
echo "Default qdisc      : $(sysctl -n net.core.default_qdisc 2>/dev/null || echo n/a)"
echo "rmem_max           : $(sysctl -n net.core.rmem_max 2>/dev/null || echo n/a)"
echo "wmem_max           : $(sysctl -n net.core.wmem_max 2>/dev/null || echo n/a)"
echo "tcp_rmem           : $(sysctl -n net.ipv4.tcp_rmem 2>/dev/null || echo n/a)"
echo "tcp_wmem           : $(sysctl -n net.ipv4.tcp_wmem 2>/dev/null || echo n/a)"
echo "slow_start_idle    : $(sysctl -n net.ipv4.tcp_slow_start_after_idle 2>/dev/null || echo n/a)"
echo "notsent_lowat      : $(sysctl -n net.ipv4.tcp_notsent_lowat 2>/dev/null || echo n/a)"
echo "somaxconn          : $(sysctl -n net.core.somaxconn 2>/dev/null || echo n/a)"
echo "file-max           : $(sysctl -n fs.file-max 2>/dev/null || echo n/a)"
echo "swappiness         : $(sysctl -n vm.swappiness 2>/dev/null || echo n/a)"
echo ""
echo "Swap:"
swapon --show 2>/dev/null || echo "  (none)"
echo ""
echo "Xray/HProxy nice & limits:"
for svc in xray haproxy; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo "  $svc: active, Nice=$(systemctl show "$svc" -p Nice 2>/dev/null | cut -d= -f2)"
    else
        echo "  $svc: not running"
    fi
done
echo ""
CC="$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '')"
if [ "$CC" = "bbr" ]; then
    echo "[OK] BBR is active."
else
    echo "[WARN] BBR is NOT active (current: ${CC:-unknown}). Throughput tuning may be limited."
fi