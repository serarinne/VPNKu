#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"
TMP_FILE="/usr/local/etc/xray/config.tmp.$$.json"
trap 'rm -f "$TMP_FILE"' EXIT

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

if ! jq '(.routing.rules[] | select(.warpRoute == true) | .outboundTag) = "WARP"' "$CONFIG_PATH" > "$TMP_FILE"; then
    echo "[ERR] Gagal memperbarui konfigurasi."
    exit 1
fi
if ! xray run -test -config "$TMP_FILE" >/dev/null 2>&1; then
    echo "[ERR] Konfigurasi tidak valid. Dibatalkan."
    exit 1
fi
mv "$TMP_FILE" "$CONFIG_PATH"
systemctl restart xray
echo "[OK] Cloudflare WARP diaktifkan."