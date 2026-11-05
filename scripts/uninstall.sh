#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

echo "[WARN] This will remove Xray, HAProxy, and VPNKu configuration."
read -rp "Continue? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "[INFO] Cancelled."
    exit 0
fi

systemctl stop xray haproxy 2>/dev/null || true
systemctl disable xray haproxy 2>/dev/null || true

rm -f /usr/bin/add-user /usr/bin/del-user /usr/bin/warp-setup /usr/bin/warp-on /usr/bin/warp-off /usr/bin/vpn-status /usr/bin/uninstall-vpn /usr/bin/traffic /usr/bin/bot-add-user /usr/bin/bot-del-user
rm -rf /etc/vps-data /usr/local/etc/xray /etc/haproxy
rm -rf /root/wgcf

echo "[OK] VPNKu removed. Xray/HAProxy binaries remain; remove manually if needed."