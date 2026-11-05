#!/bin/bash
# Telegram bot polling loop for VPNKu
set -uo pipefail

BOT_TOKEN="YOUR_BOT_TOKEN_HERE"
ADMIN_CHAT_ID="YOUR_CHAT_ID_HERE"

API="https://api.telegram.org/bot${BOT_TOKEN}"
OFFSET=0

send_msg() {
    local chat_id="$1"; local text="$2"
    curl -s -X POST "${API}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" >/dev/null
}

send_menu() {
    local chat_id="$1"; local text="$2"
    local kb='{"keyboard":[["/status","/traffic"],["/warpon","/warpoff"],["/restartxray","/restarthaproxy"],["/restartvps"],["/add","/del","/genconfig"],["/config","/info"],["/backup"]],"resize_keyboard":true,"one_time_keyboard":false}'
    curl -s -X POST "${API}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" \
        --data-urlencode "reply_markup=${kb}" >/dev/null
}

while true; do
    RESP=$(curl -s "${API}/getUpdates?offset=${OFFSET}&timeout=30" || true)
    python3 - "$RESP" <<'PY' > /tmp/vpnku_updates.txt || true
import sys, json
data = json.loads(sys.argv[1])
for u in data.get("result", []):
    uid = u["update_id"]
    msg = u.get("message", {})
    chat = msg.get("chat", {}).get("id")
    text = msg.get("text", "")
    print(f"{uid}|{chat}|{text}")
PY

    while IFS='|' read -r UPD CHAT TEXT; do
        [ -z "$UPD" ] && continue
        OFFSET=$((UPD + 1))
        [ "$CHAT" != "$ADMIN_CHAT_ID" ] && continue

        case "$TEXT" in
            /start)
                send_menu "$CHAT" "VPNKu Bot ready. Use the menu or type commands." ;;
            /status)
                send_msg "$CHAT" "$(vpn-status)" ;;
            /traffic)
                send_msg "$CHAT" "$(traffic)" ;;
            /warpon)
                send_msg "$CHAT" "$(warp-on)" ;;
            /warpoff)
                send_msg "$CHAT" "$(warp-off)" ;;
            /restartxray)
                systemctl restart xray && send_msg "$CHAT" "Xray restarted." || send_msg "$CHAT" "Failed to restart Xray." ;;
            /restarthaproxy)
                systemctl restart haproxy && send_msg "$CHAT" "HAProxy restarted." || send_msg "$CHAT" "Failed to restart HAProxy." ;;
            /restartvps)
                send_msg "$CHAT" "Rebooting VPS..."
                sleep 2
                reboot ;;
            /genconfig)
                send_msg "$CHAT" "Usage: /genconfig <email>" ;;
            /backup)
                BAK="/root/vpn-backups/xray-$(date +%Y%m%d-%H%M%S).json"
                mkdir -p /root/vpn-backups
                cp /usr/local/etc/xray/config.json "$BAK"
                curl -s -X POST "${API}/sendDocument" \
                    -F "chat_id=${CHAT}" \
                    -F "document=@${BAK}" >/dev/null
                send_msg "$CHAT" "Xray config backup sent." ;;
            /genconfig\ *)
                read -r _ EMAIL <<< "$TEXT"
                if [ -z "$EMAIL" ]; then
                    send_msg "$CHAT" "Usage: /genconfig <email>"
                else
                    if gen-config "$EMAIL" >/tmp/genconfig.out 2>&1; then
                        curl -s -X POST "${API}/sendDocument" \
                            -F "chat_id=${CHAT}" \
                            -F "document=@/root/vpn-configs/${EMAIL}.txt" >/dev/null
                        send_msg "$CHAT" "Config generated and sent as file."
                    else
                        send_msg "$CHAT" "Failed to generate config."
                    fi
                fi
                ;;
            /add)
                send_msg "$CHAT" "Usage: /add <email> [uuid]" ;;
            /info)
                DOMAIN=$(cat /etc/vps-data/domain)
                send_msg "$CHAT" "Domain: ${DOMAIN}
Port: 443
WS: /vmess , /vless
HU: /vmess-hu , /vless-hu
gRPC: vmess-grpc , vless-grpc" ;;
            /config)
                send_msg "$CHAT" "Usage: /config <email>" ;;
            /config\ *)
                read -r _ EMAIL <<< "$TEXT"
                if [ -z "$EMAIL" ]; then
                    send_msg "$CHAT" "Usage: /config <email>"
                else
                    if gen-config "$EMAIL" >/tmp/genconfig.out 2>&1; then
                        curl -s -X POST "${API}/sendDocument" \
                            -F "chat_id=${CHAT}" \
                            -F "document=@/root/vpn-configs/${EMAIL}.txt" >/dev/null
                        send_msg "$CHAT" "Config generated and sent as file."
                    else
                        send_msg "$CHAT" "Failed to generate config."
                    fi
                fi
                ;;
            /add\ *)
                read -r _ EMAIL UUID <<< "$TEXT"
                if [ -z "$EMAIL" ]; then
                    send_msg "$CHAT" "Usage: /add <email> [uuid]"
                else
                    if [ -z "$UUID" ]; then
                        UUID=$(xray uuid)
                    fi
                    RES=$(bot-add-user "$EMAIL" "$UUID")
                    if [ "$RES" = "1" ]; then
                        send_msg "$CHAT" "User added: $EMAIL
UUID: $UUID"
                        gen-config "$EMAIL" >/tmp/genconfig.out 2>&1 || true
                        if [ -f "/root/vpn-configs/${EMAIL}.txt" ]; then
                            curl -s -X POST "${API}/sendDocument" \
                                -F "chat_id=${CHAT}" \
                                -F "document=@/root/vpn-configs/${EMAIL}.txt" >/dev/null
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
                if [ -z "$EMAIL" ]; then
                    send_msg "$CHAT" "Usage: /del <email>"
                else
                    RES=$(bot-del-user "$EMAIL")
                    if [ "$RES" = "1" ]; then
                        send_msg "$CHAT" "User deleted: $EMAIL"
                    else
                        send_msg "$CHAT" "Failed to delete user: $EMAIL"
                    fi
                fi
                ;;
            *)
                send_msg "$CHAT" "Unknown command. Use /start for help." ;;
        esac
    done < /tmp/vpnku_updates.txt

    sleep 1
done