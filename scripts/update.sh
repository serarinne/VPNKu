#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

BASE="https://raw.githubusercontent.com/serarinne/VPNKu/main"
echo "[INFO] Updating VPNKu scripts..."

fetch() {
  local url="$1"
  if [[ "$url" == *\?* ]]; then
    url="${url}&_=$(date +%s%N)"
  else
    url="${url}?_=$(date +%s%N)"
  fi
  if ! wget -q --inet4-only --header="Cache-Control: no-cache, no-store, must-revalidate" --header="Pragma: no-cache" "$url" -O "$2"; then
    echo "[ERR] Failed to download $1"
    wget --inet4-only --header="Cache-Control: no-cache, no-store, must-revalidate" --header="Pragma: no-cache" "$url" -O "$2" || true
    return 1
  fi
  chmod +x "$2"
}

mkdir -p /usr/bin /opt/vpnku/config

fetch "$BASE/scripts/account-add.sh" "/usr/bin/add-user"
fetch "$BASE/scripts/account-del.sh" "/usr/bin/del-user"
fetch "$BASE/scripts/account-expire.sh" "/usr/bin/expire-accounts"
fetch "$BASE/scripts/gen-config.sh" "/usr/bin/gen-config"
fetch "$BASE/scripts/status.sh" "/usr/bin/vpn-status"
fetch "$BASE/scripts/traffic.sh" "/usr/bin/traffic"
fetch "$BASE/scripts/warp-setup.sh" "/usr/bin/warp-setup"
fetch "$BASE/scripts/warp-on.sh" "/usr/bin/warp-on"
fetch "$BASE/scripts/warp-off.sh" "/usr/bin/warp-off"
fetch "$BASE/scripts/uninstall.sh" "/usr/bin/uninstall-vpn"
fetch "$BASE/scripts/setup-telegram-bot.sh" "/usr/bin/setup-telegram-bot"
fetch "$BASE/bot/account-add.sh" "/usr/bin/bot-add-user"
fetch "$BASE/bot/account-del.sh" "/usr/bin/bot-del-user"
fetch "$BASE/bot/telegram-bot.sh" "/opt/vpnku-bot/telegram-bot.sh"

# Update config templates (not live config)
fetch "$BASE/config/xray.json" "/opt/vpnku/config/xray.json" || true
fetch "$BASE/config/haproxy.cfg" "/opt/vpnku/config/haproxy.cfg" || true

# Restart bot if running
if systemctl is-active --quiet vpnku-bot 2>/dev/null; then
    systemctl restart vpnku-bot
    echo "[OK] Telegram bot restarted."
fi

echo "[OK] Update complete. Live Xray/HAProxy config not overwritten."
echo "[INFO] To apply new Xray template, back up and replace manually:" 
echo "  cp /usr/local/etc/xray/config.json /usr/local/etc/xray/config.json.bak"
echo "  cp /opt/vpnku/config/xray.json /usr/local/etc/xray/config.json"
echo "  xray run -test -config /usr/local/etc/xray/config.json && systemctl restart xray"