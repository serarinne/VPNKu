#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"

CLIENT_EMAIL="${1:-}"
if [ -z "$CLIENT_EMAIL" ]; then
    echo "[ERR] Email cannot be empty." >&2
    echo "0"
    exit 1
fi

TMP_FILE="/usr/local/etc/xray/config.tmp.$$.json"
if ! jq --arg email "$CLIENT_EMAIL" '
  .inbounds |= map(
    if (.settings.clients | type) == "array" then
      .settings.clients |= map(select(.email != $email))
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