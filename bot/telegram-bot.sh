#!/bin/bash
# Telegram bot polling loop for VPNKu
set -o pipefail

BOT_TOKEN="$(cat /etc/vps-data/bot-token 2>/dev/null || true)"
ADMIN_CHAT_ID="$(cat /etc/vps-data/bot-admin 2>/dev/null || true)"
BOT_TOKEN="${BOT_TOKEN:-YOUR_BOT_TOKEN_HERE}"
ADMIN_CHAT_ID="${ADMIN_CHAT_ID:-YOUR_CHAT_ID_HERE}"
# Trim whitespace/newlines just in case
BOT_TOKEN="${BOT_TOKEN//[[:space:]]/}"
ADMIN_CHAT_ID="${ADMIN_CHAT_ID//[[:space:]]/}"

API="https://api.telegram.org/bot${BOT_TOKEN}"
OFFSET=0
LOG="/var/log/vpnku-bot.log"

log() { echo "[$(date '+%F %T')] $*" >> "$LOG" 2>/dev/null || true; }

# Clear any stale webhook so getUpdates (polling) works
curl -s "${API}/deleteWebhook" >/dev/null 2>&1 || true

send_msg() {
    local chat_id="$1"; local text="$2"
    [ -z "$chat_id" ] && return 0
    curl -s -X POST "${API}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" >/dev/null 2>&1 || true
}

send_menu() {
    local chat_id="$1"; local text="$2"
    local kb='{"keyboard":[["/status","/traffic"],["/warpon","/warpoff"],["/restartxray","/restarthaproxy"],["/restartvps"],["/add","/del","/genconfig"],["/config","/info"],["/backup"]],"resize_keyboard":true,"one_time_keyboard":false}'
    [ -z "$chat_id" ] && return 0
    curl -s -X POST "${API}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" \
        --data-urlencode "reply_markup=${kb}" >/dev/null 2>&1 || true
}

log "Bot started (admin=${ADMIN_CHAT_ID})"

while true; do
    RESP=$(curl -s "${API}/getUpdates?offset=${OFFSET}&timeout=30" 2>/dev/null || true)

    # Pass the response through stdin to python (code given via -c so stdin
    # is free for the data). Avoids the heredoc/pipe conflict that caused
    # "printf: write error: Broken pipe".
    printf '%s' "$RESP" | python3 -c '
import sys, json
raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw else {}
except Exception:
    data = {}
for u in (data or {}).get("result", []):
    uid = u.get("update_id")
    msg = u.get("message", {}) or {}
    chat = msg.get("chat", {}).get("id")
    text = msg.get("text", "") or ""
    if uid is None:
        continue
    print(f"{uid}|{chat}|{text}")
' 2>/dev/null > /tmp/vpnku_updates.txt || true

    while IFS='|' read -r UPD CHAT TEXT; do
        [ -z "${UPD:-}" ] && continue
        # Only advance offset for numeric update ids
        case "$UPD" in
            ''|*[!0-9]*) continue ;;
        esac
        OFFSET=$((UPD + 1))

        [ "${CHAT:-}" != "$ADMIN_CHAT_ID" ] && continue
        [ -z "${CHAT:-}" ] && continue

        case "$TEXT" in
            /start)
                send_menu "$CHAT" "VPNKu Bot ready. Use the menu or type commands." ;;
            /status)
                send_msg "$CHAT" "$(vpn-status 2>/dev/null)" ;;
            /traffic)
                send_msg "$CHAT" "$(traffic 2>/dev/null)" ;;
            /warpon)
                send_msg "$CHAT" "$(warp-on 2>/dev/null)" ;;
            /warpoff)
                send_msg "$CHAT" "$(warp-off 2>/dev/null)" ;;
            /restartxray)
                if systemctl restart xray 2>/dev/null; then send_msg "$CHAT" "Xray restarted."; else send_msg "$CHAT" "Failed to restart Xray."; fi ;;
            /restarthaproxy)
                if systemctl restart haproxy 2>/dev/null; then send_msg "$CHAT" "HAProxy restarted."; else send_msg "$CHAT" "Failed to restart HAProxy."; fi ;;
            /restartvps)
                send_msg "$CHAT" "Rebooting VPS..."
                sleep 2
                reboot ;;
            /genconfig)
                send_msg "$CHAT" "Usage: /genconfig <email>" ;;
            /backup)
                BAK="/root/vpn-backups/xray-$(date +%Y%m%d-%H%M%S).json"
                mkdir -p /root/vpn-backups
                cp /usr/local/etc/xray/config.json "$BAK" 2>/dev/null || true
                curl -s -X POST "${API}/sendDocument" \
                    -F "chat_id=${CHAT}" \
                    -F "document=@${BAK}" >/dev/null 2>&1 || true
                send_msg "$CHAT" "Xray config backup sent." ;;
            /genconfig\ *)
                read -r _ EMAIL <<< "$TEXT"
                if [ -z "${EMAIL:-}" ]; then
                    send_msg "$CHAT" "Usage: /genconfig <email>"
                else
                    if gen-config "$EMAIL" >/tmp/genconfig.out 2>&1; then
                        curl -s -X POST "${API}/sendDocument" \
                            -F "chat_id=${CHAT}" \
                            -F "document=@/root/vpn-configs/${EMAIL}.txt" >/dev/null 2>&1 || true
                        send_msg "$CHAT" "Config generated and sent as file."
                    else
                        send_msg "$CHAT" "Failed to generate config."
                    fi
                fi
                ;;
            /info)
                DOMAIN=$(cat /etc/vps-data/domain 2>/dev/null || true)
                send_msg "$CHAT" "Domain: ${DOMAIN}
Port: 443
WS: /vmess , /vless
HU: /vmess-hu , /vless-hu
gRPC: vmess-grpc , vless-grpc" ;;
            /config)
                send_msg "$CHAT" "Usage: /config <email>" ;;
            /config\ *)
                read -r _ EMAIL <<< "$TEXT"
                if [ -z "${EMAIL:-}" ]; then
                    send_msg "$CHAT" "Usage: /config <email>"
                else
                    if gen-config "$EMAIL" >/tmp/genconfig.out 2>&1; then
                        curl -s -X POST "${API}/sendDocument" \
                            -F "chat_id=${CHAT}" \
                            -F "document=@/root/vpn-configs/${EMAIL}.txt" >/dev/null 2>&1 || true
                        send_msg "$CHAT" "Config generated and sent as file."
                    else
                        send_msg "$CHAT" "Failed to generate config."
                    fi
                fi
                ;;
            /add)
                send_msg "$CHAT" "Usage: /add <email> [uuid]" ;;
            /add\ *)
                read -r _ EMAIL UUID <<< "$TEXT"
                if [ -z "${EMAIL:-}" ]; then
                    send_msg "$CHAT" "Usage: /add <email> [uuid]"
                else
                    if [ -z "${UUID:-}" ]; then
                        UUID=$(xray uuid 2>/dev/null || true)
                    fi
                    RES=$(bot-add-user "$EMAIL" "$UUID" 2>/dev/null || true)
                    if [ "$RES" = "1" ]; then
                        send_msg "$CHAT" "User added: $EMAIL
UUID: $UUID"
                        gen-config "$EMAIL" >/tmp/genconfig.out 2>&1 || true
                        if [ -f "/root/vpn-configs/${EMAIL}.txt" ]; then
                            curl -s -X POST "${API}/sendDocument" \
                                -F "chat_id=${CHAT}" \
                                -F "document=@/root/vpn-configs/${EMAIL}.txt" >/dev/null 2>&1 || true
                        fi
                    else
                        send_msg "$CHAT" "Failed to add user: $EMAIL"
                    fi
                fi
                ;;
            /del)
                send_msg "$CHAT" "Usage: /del <email>" ;;
            /del\ *)
                read -r _ EMAIL <<< "$TEXT"
                if [ -z "${EMAIL:-}" ]; then
                    send_msg "$CHAT" "Usage: /del <email>"
                else
                    RES=$(bot-del-user "$EMAIL" 2>/dev/null || true)
                    if [ "$RES" = "1" ]; then
                        send_msg "$CHAT" "User deleted: $EMAIL"
                    else
                        send_msg "$CHAT" "Failed to delete user: $EMAIL"
                    fi
                fi
                ;;
            *)
                # Only reply to non-empty text
                if [ -n "${TEXT:-}" ]; then
                    send_msg "$CHAT" "Unknown command. Use /start for help."
                fi
                ;;
        esac
    done < /tmp/vpnku_updates.txt

    sleep 1
done