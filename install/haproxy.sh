#!/bin/bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

DOMAIN=$(cat /etc/vps-data/domain)

echo "[INFO] Starting HAProxy installation & configuration..."

apt-get remove --purge nginx* nginx-common* nginx-full* -y >/dev/null 2>&1 || true
apt autoremove -y >/dev/null 2>&1 || true

# Add the official HAProxy repository so the latest stable version is installed
# (instead of the older version shipped by the OS repository).
. /etc/os-release
case "${ID:-}" in
  ubuntu)
    if ! command -v add-apt-repository >/dev/null 2>&1; then
      apt-get install -y software-properties-common >/dev/null 2>&1
    fi
    add-apt-repository -y ppa:vbernat/haproxy-3.0 >/dev/null 2>&1
    ;;
  debian)
    apt-get install -y curl gnupg lsb-release >/dev/null 2>&1
    curl -4 -fsSL https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor -o /usr/share/keyrings/haproxy.debian.net.gpg
    echo "deb [signed-by=/usr/share/keyrings/haproxy.debian.net.gpg] http://haproxy.debian.net $(lsb_release -cs)-backports-2.8 main" > /etc/apt/sources.list.d/haproxy.list
    ;;
  *)
    echo "[WARN] Unsupported OS (${ID:-unknown}); falling back to the OS repository version of HAProxy."
    ;;
esac

apt-get update -y >/dev/null 2>&1 || true
apt install haproxy -y >/dev/null 2>&1

# Combine certificate and key into a single PEM file (HAProxy format)
cat /etc/vps-data/cert.crt /etc/vps-data/cert.key > /etc/vps-data/haproxy.pem
chmod 600 /etc/vps-data/haproxy.pem

wget -q --inet4-only "https://raw.githubusercontent.com/serarinne/VPNKu/main/config/haproxy.cfg?_=$(date +%s%N)" -O /etc/haproxy/haproxy.cfg

haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl daemon-reload >/dev/null 2>&1
systemctl enable haproxy >/dev/null 2>&1
systemctl restart haproxy >/dev/null 2>&1

echo ""
echo "[OK] HAProxy installation & configuration complete!"