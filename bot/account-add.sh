#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"

CLIENT_EMAIL="${1:-}"
NEW_UUID="${2:-}"

if [ -z "$CLIENT_EMAIL" ]; then
    echo "[ERR] Email cannot be empty."
    echo "0"
    exit 1
fi

if [ -z "$NEW_UUID" ]; then
    NEW_UUID=$(xray uuid)
fi

HOUR=$(date +%H)
if [ "$HOUR" -ge 12 ]; then
    DAYS=31
else
    DAYS=30
fi
EXPIRY_MS=$(( ($(date +%s) + DAYS*24*3600) * 1000 ))

if ! echo "$NEW_UUID" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'; then
    echo "[ERR] Invalid UUID."
    echo "0"
    exit 1
fi

CLIENT_EXISTS=$(jq --arg e "$CLIENT_EMAIL" '[.inbounds[].settings.clients[]? | select(.email == $e)] | length' "$CONFIG_PATH")
if [ "$CLIENT_EXISTS" -gt 0 ]; then
    echo "[ERR] Client with email '${CLIENT_EMAIL}' already exists."
    echo "0"
    exit 1
fi

TMP_FILE="/usr/local/etc/xray/config.json.tmp.$$"
if ! jq --arg email "$CLIENT_EMAIL" --arg uuid "$NEW_UUID" --argjson expiry "$EXPIRY_MS" '
  .inbounds |= map(
    if (.settings.clients | type) == "array" then
      .settings.clients += [
        if .protocol == "vmess" then
          {"id": $uuid, "alterId": 0, "level": 0, "security": "auto", "email": $email, "expiryTime": $expiry}
        elif .protocol == "vless" then
          {"id": $uuid, "level": 0, "email": $email, "expiryTime": $expiry}
        else
          empty
        end
      ]
    else
      .
    end
  )
' "$CONFIG_PATH" > "$TMP_FILE"; then
    rm -f "$TMP_FILE"
    echo "0"
    exit 1
fi

if ! xray run -test -config "$TMP_FILE" >/dev/null 2>&1; then
    rm -f "$TMP_FILE"
    echo "0"
    exit 1
fi

mv "$TMP_FILE" "$CONFIG_PATH"
systemctl restart xray
echo "1"