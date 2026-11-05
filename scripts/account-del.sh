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

echo "Current clients:"
jq -r '[.inbounds[].settings.clients[]?.email] | unique | .[]' "$CONFIG_PATH" | cat -n

CLIENT_COUNT=$(jq '[.inbounds[].settings.clients[]?] | length' "$CONFIG_PATH")
if [ "$CLIENT_COUNT" -eq 0 ]; then
    echo "[INFO] No clients to delete."
    exit 0
fi

echo ""
read -rp "Enter email of client to delete: " CLIENT_EMAIL
if [ -z "$CLIENT_EMAIL" ]; then
    echo "[ERR] Email cannot be empty."
    exit 1
fi

EXISTS=$(jq --arg e "$CLIENT_EMAIL" '[.inbounds[].settings.clients[]? | select(.email == $e)] | length' "$CONFIG_PATH")
if [ "$EXISTS" -eq 0 ]; then
    echo "[ERR] Client with email '$CLIENT_EMAIL' not found."
    exit 1
fi

cp "$CONFIG_PATH" "$BACKUP_PATH"
TMP_FILE="/usr/local/etc/xray/config.json.tmp.$$"
if ! jq --arg email "$CLIENT_EMAIL" '
  .inbounds |= map(
    if (.settings.clients | type) == "array" then
      .settings.clients |= map(select(.email != $email))
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

echo "[OK] Client '$CLIENT_EMAIL' deleted from all protocols & transports."

read -rp "Press [Enter] to continue"
exit 0