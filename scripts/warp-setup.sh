#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"
TMP_FILE="/usr/local/etc/xray/config.json.tmp.$$"
trap 'rm -f "$TMP_FILE"' EXIT

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) WGCF_ARCH="amd64" ;;
    aarch64|arm64) WGCF_ARCH="arm64" ;;
    *) echo "[ERR] Unsupported architecture: $ARCH"; exit 1 ;;
esac

WORKDIR="/root/wgcf"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

WGCF_VERSION="2.2.20"
WGCF_URL="https://github.com/ViRb3/wgcf/releases/download/v${WGCF_VERSION}/wgcf_${WGCF_VERSION}_linux_${WGCF_ARCH}"

echo "[INFO] Downloading wgcf..."
if ! wget -q "$WGCF_URL" -O wgcf; then
    echo "[ERR] Failed to download wgcf."
    exit 1
fi
chmod +x wgcf

echo "[INFO] Registering Cloudflare WARP account..."
./wgcf register --accept-tos >/dev/null 2>&1

echo "[INFO] Generating WireGuard profile..."
./wgcf generate >/dev/null 2>&1

if [ ! -f wgcf-profile.conf ]; then
    echo "[ERR] Failed to create WARP profile."
    exit 1
fi

PRIVATE_KEY=$(grep -E '^PrivateKey' wgcf-profile.conf | awk -F'= ' '{print $2}' | tr -d ' ')
ADDRESSES=$(grep -E '^Address' wgcf-profile.conf | awk -F'= ' '{print $2}' | tr -d ' ')

if [ -z "$PRIVATE_KEY" ] || [ -z "$ADDRESSES" ]; then
    echo "[ERR] Failed to read WARP key/address."
    exit 1
fi

ADDR_JSON=$(echo "$ADDRESSES" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | jq -R . | jq -s .)

if ! jq --arg key "$PRIVATE_KEY" --argjson addrs "$ADDR_JSON" '
  .outbounds |= map(if .tag == "WARP" then .settings = (.settings + {"secretKey": $key, "address": $addrs}) else . end)
' "$CONFIG_PATH" > "$TMP_FILE"; then
    echo "[ERR] Failed to update configuration."
    exit 1
fi

if ! xray run -test -config "$TMP_FILE" >/dev/null 2>&1; then
    echo "[ERR] Invalid configuration. Aborted."
    exit 1
fi

mv "$TMP_FILE" "$CONFIG_PATH"
systemctl restart xray
echo "[OK] Cloudflare WARP configured successfully."
echo "   Private Key : $PRIVATE_KEY"
echo "   Address     : $ADDRESSES"
echo "[INFO] Use 'warp-on' to enable, 'warp-off' to disable."