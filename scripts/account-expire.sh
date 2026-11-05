#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"
LOG="/var/log/vpnku-expire.log"

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

# Collect expired emails (expiryTime in ms, now in s -> *1000)
EXPIRED=$(jq -r '[.inbounds[].settings.clients[]? | select((.expiryTime // 0) > 0 and .expiryTime < (now*1000)) | .email] | unique | .[]' "$CONFIG_PATH" 2>/dev/null || true)

if [ -z "$EXPIRED" ]; then
    exit 0
fi

CHANGED=0
for EMAIL in $EXPIRED; do
    TMP_FILE="/usr/local/etc/xray/config.json.tmp.$$"
    if jq --arg email "$EMAIL" '
      .inbounds |= map(
        if (.settings.clients | type) == "array" then
          .settings.clients |= map(select(.email != $email))
        else
          .
        end
      )
    ' "$CONFIG_PATH" > "$TMP_FILE"; then
        if xray run -test -config "$TMP_FILE" >/dev/null 2>&1; then
            mv "$TMP_FILE" "$CONFIG_PATH"
            echo "$(date '+%Y-%m-%d %H:%M:%S') Expired & removed: $EMAIL" >> "$LOG"
            CHANGED=1
        else
            rm -f "$TMP_FILE"
        fi
    else
        rm -f "$TMP_FILE"
    fi
done

if [ "$CHANGED" -eq 1 ]; then
    systemctl restart xray
fi