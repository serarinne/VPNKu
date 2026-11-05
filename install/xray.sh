#!/bin/bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

DOMAIN=$(cat /etc/vps-data/domain)

echo "[INFO] Starting Xray-Core installation & configuration..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1

mkdir -p /var/log/xray
chown www-data:www-data /var/log/xray
chmod 755 /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

wget -q --inet4-only https://raw.githubusercontent.com/serarinne/VPNKu/main/config/xray.json -O /usr/local/etc/xray/config.json

systemctl daemon-reload >/dev/null 2>&1
systemctl enable xray >/dev/null 2>&1
systemctl restart xray >/dev/null 2>&1
echo ""
echo "[OK] Xray-Core installation & configuration complete!"