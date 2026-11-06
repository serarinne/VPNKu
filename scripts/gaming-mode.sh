#!/bin/bash
# Apply latency-oriented (gaming) tuning on top of optimize.sh.
# Reduces bufferbloat; keep WARP off and use HTTPUpgrade transport for gaming.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERR] This script must be run as root" 1>&2
    exit 1
fi

SYSCTL_CONFIG="/etc/sysctl.conf"

set_sysctl_config() {
    local key="$1" value="$2" key_re
    key_re="$(printf '%s' "$key" | sed 's/[.]/\\./g')"
    sed -i -E "/^[[:space:]]*#?[[:space:]]*${key_re}[[:space:]]*=/d" "$SYSCTL_CONFIG"
    echo "${key}=${value}" >> "$SYSCTL_CONFIG"
}

echo "[INFO] Applying gaming/latency tuning..."

# Smaller buffers -> less bufferbloat, lower latency under load
set_sysctl_config "net.core.rmem_default" "131072"
set_sysctl_config "net.core.wmem_default" "131072"
set_sysctl_config "net.core.rmem_max" "16777216"
set_sysctl_config "net.core.wmem_max" "16777216"
set_sysctl_config "net.ipv4.tcp_rmem" "4096 87380 16777216"
set_sysctl_config "net.ipv4.tcp_wmem" "4096 65536 16777216"
set_sysctl_config "net.ipv4.tcp_notsent_lowat" "4096"
set_sysctl_config "net.core.netdev_max_backlog" "65536"

# Keep BBR + fq (already set by optimize.sh)
set_sysctl_config "net.core.default_qdisc" "fq"

if sysctl -p >/dev/null 2>&1; then
    echo "[OK] Gaming tuning applied."
else
    echo "[WARN] Some values could not be applied."
fi

echo ""
echo "[INFO] Recommendations for gaming:"
echo "  - Use HTTPUpgrade transport (lowest overhead)."
echo "  - Keep WARP OFF: run 'warp-off'."
echo "  - Pick a VPS close to you and the game server."
echo "  - Avoid downloads/streams while playing."
if command -v warp-off >/dev/null 2>&1; then
    echo "[INFO] Disabling WARP now..."
    warp-off || true
fi