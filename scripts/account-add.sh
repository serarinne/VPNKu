#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"
BACKUP_PATH="/usr/local/etc/xray/config.json.bak"

cleanup() { rm -f /usr/local/etc/xray/config.json.tmp.*; }
trap cleanup EXIT

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

read -rp "Enter email for new client: " CLIENT_EMAIL
if [ -z "$CLIENT_EMAIL" ]; then
    echo "[ERR] Email cannot be empty."
    exit 1
fi

CLIENT_EXISTS=$(jq --arg e "$CLIENT_EMAIL" '[.inbounds[].settings.clients[]? | select(.email == $e)] | length' "$CONFIG_PATH")
if [ "$CLIENT_EXISTS" -gt 0 ]; then
    echo "[ERR] Client with email '$CLIENT_EMAIL' already exists."
    exit 1
fi

NEW_UUID=$(xray uuid)
HOUR=$(date +%H)
if [ "$HOUR" -ge 12 ]; then
    DAYS=31
else
    DAYS=30
fi
EXPIRY_MS=$(( ($(date +%s) + DAYS*24*3600) * 1000 ))

cp "$CONFIG_PATH" "$BACKUP_PATH"

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
    echo "[ERR] Failed to update configuration."
    rm -f "$TMP_FILE"
    exit 1
fi

if ! xray run -test -config "$TMP_FILE" >/dev/null 2>&1; then
    echo "[ERR] Invalid configuration. Aborted."
    rm -f "$TMP_FILE"
    exit 1
fi

mv "$TMP_FILE" "$CONFIG_PATH"
systemctl restart xray

echo "[OK] Client added to all protocols & transports!"
echo "   Email : $CLIENT_EMAIL"
echo "   UUID  : $NEW_UUID"
echo "   Expiry: ${DAYS} days"
echo "   Run 'gen-config $CLIENT_EMAIL' to get share links."

read -rp "Press [Enter] to continue"
exit 0