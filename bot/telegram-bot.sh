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
    local chat_id="$1"; local text="$2"; local mode="${3:-}"
    [ -z "$chat_id" ] && return 0
    local resp
    if [ -n "$mode" ]; then
        resp=$(curl -s -X POST "${API}/sendMessage" \
            -d "chat_id=${chat_id}" \
            --data-urlencode "text=${text}" \
            --data-urlencode "parse_mode=${mode}" 2>&1)
    else
        resp=$(curl -s -X POST "${API}/sendMessage" \
            -d "chat_id=${chat_id}" \
            --data-urlencode "text=${text}" 2>&1)
    fi
    printf '[%s] send_msg: %s\n' "$(date '+%F %T')" "$resp" >> /tmp/vpnku-send.log 2>/dev/null || true
}

html_escape() {
    python3 -c 'import sys, html; print(html.escape(sys.stdin.read()), end="")'
}

build_kb() {
    python3 - "$1" <<'PY'
import json, sys
path = sys.argv[1]
label = ""
rows = []
for raw in open(path, encoding="utf-8", errors="replace"):
    line = raw.strip()
    if line.startswith("---") and line.endswith("---"):
        label = line.strip("- ").strip()
        continue
    if line.startswith("vmess://") or line.startswith("vless://"):
        rows.append([{"text": "Copy " + label, "copy_text": {"text": line}}])
print(json.dumps({"inline_keyboard": rows}))
PY
}

send_inline() {
    local chat_id="$1"; local text="$2"; local kb="$3"
    [ -z "$chat_id" ] && return 0
    local resp
    resp=$(curl -s -X POST "${API}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "reply_markup=${kb}" 2>&1)
    printf '[%s] send_inline: %s\n' "$(date '+%F %T')" "$resp" >> /tmp/vpnku-send.log 2>/dev/null || true
}

send_menu() {
    local chat_id="$1"; local text="$2"
    local kb='{"keyboard":[["Status Server","Traffic User"],["WARP On","WARP Off"],["Restart Xray","Restart HAProxy"],["Restart VPS"],["Add User","Delete User","User List"],["Config"],["Backup Config"],["Help"],["Main Menu"]],"resize_keyboard":true,"one_time_keyboard":false}'
    [ -z "$chat_id" ] && return 0
    curl -s -X POST "${API}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "reply_markup=${kb}" >/dev/null 2>&1 || true
}

log "Bot started (admin=${ADMIN_CHAT_ID})"

# Emoji constants (ANSI-C quoting keeps source ASCII-safe)
E_OK=$'\U2705'
E_ERR=$'\U274C'
E_STATUS=$'\U1F4CA'
E_TRAFFIC=$'\U1F4C8'
E_WARP=$'\U1F310'
E_RESTART=$'\U1F504'
E_REBOOT=$'\U1F501'
E_USER=$'\U1F464'
E_CONFIG=$'\U1F4C4'
E_BACKUP=$'\U1F4BE'
E_HELP=$'\U2753'
E_MENU=$'\U1F4CB'
E_ROCKET=$'\U1F680'

while true; do
    # Fetch updates directly to a file (no pipe/printf involved) to avoid
    # "Broken pipe" errors entirely.
    curl -s "${API}/getUpdates?offset=${OFFSET}&timeout=30" -o /tmp/vpnku_raw.txt 2>/dev/null || true

    python3 - 2>/dev/null > /tmp/vpnku_updates.txt <<'PY' || true
import json
try:
    raw = open("/tmp/vpnku_raw.txt").read()
except Exception:
    raw = ""
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
PY

    while IFS='|' read -r UPD CHAT TEXT; do
        [ -z "${UPD:-}" ] && continue
        # Only advance offset for numeric update ids
        case "$UPD" in
            ''|*[!0-9]*) continue ;;
        esac
        OFFSET=$((UPD + 1))

        [ "${CHAT:-}" != "$ADMIN_CHAT_ID" ] && continue
        [ -z "${CHAT:-}" ] && continue

        # Normalize reply-keyboard button labels to commands
        case "$TEXT" in
            "Status Server") TEXT="/status" ;;
            "Traffic User") TEXT="/traffic" ;;
            "WARP On") TEXT="/warpon" ;;
            "WARP Off") TEXT="/warpoff" ;;
            "Restart Xray") TEXT="/restartxray" ;;
            "Restart HAProxy") TEXT="/restarthaproxy" ;;
            "Restart VPS") TEXT="/restartvps" ;;
            "Add User") TEXT="/add" ;;
            "Delete User") TEXT="/del" ;;
            "User List") TEXT="/users" ;;
            "Config") TEXT="/config" ;;
            "Backup Config") TEXT="/backup" ;;
            "Help") TEXT="/help" ;;
            "Main Menu") TEXT="/start" ;;
            /menu) TEXT="/start" ;;
        esac

        case "$TEXT" in
            /start)
                send_menu "$CHAT" "<b>${E_ROCKET} VPNKu Bot</b> - VPN Management Panel

Welcome! Use the menu buttons below or type commands directly.

<b>${E_MENU} Command List:</b>
/status - ${E_STATUS} Service status &amp; domain
/traffic - ${E_TRAFFIC} Bandwidth usage per user
/warpon - ${E_WARP} Enable Cloudflare WARP
/warpoff - ${E_WARP} Disable WARP (direct)
/restartxray - ${E_RESTART} Restart Xray service
/restarthaproxy - ${E_RESTART} Restart HAProxy service
/restartvps - ${E_REBOOT} Reboot VPS
/add &lt;email&gt; [uuid] - ${E_USER} Add new user
/del &lt;email&gt; - ${E_USER} Delete user
/users - ${E_USER} List users &amp; expiry
/config &lt;email&gt; - ${E_CONFIG} Generate share link
/backup - ${E_BACKUP} Backup Xray config
/help - ${E_HELP} Detailed help for each feature
/menu - ${E_MENU} Show main menu again

Type /help for detailed explanations." ;;
            /status)
                OUT=$(vpn-status 2>/dev/null)
                ESC=$(printf '%s' "$OUT" | html_escape)
                send_msg "$CHAT" "<b>${E_STATUS} Status Server</b>

<pre>$ESC</pre>" "HTML" ;;
            /traffic)
                OUT=$(traffic 2>/dev/null)
                ESC=$(printf '%s' "$OUT" | html_escape)
                send_msg "$CHAT" "<b>${E_TRAFFIC} Traffic Usage</b>

<pre>$ESC</pre>" "HTML" ;;
            /warpon)
                OUT=$(warp-on 2>/dev/null)
                ESC=$(printf '%s' "$OUT" | html_escape)
                send_msg "$CHAT" "<b>${E_WARP} WARP</b>

<pre>$ESC</pre>" "HTML" ;;
            /warpoff)
                OUT=$(warp-off 2>/dev/null)
                ESC=$(printf '%s' "$OUT" | html_escape)
                send_msg "$CHAT" "<b>${E_WARP} WARP</b>

<pre>$ESC</pre>" "HTML" ;;
            /restartxray)
                if systemctl restart xray 2>/dev/null; then send_msg "$CHAT" "${E_OK} <b>Xray</b> restarted successfully." "HTML"; else send_msg "$CHAT" "${E_ERR} <b>Xray</b> failed to restart." "HTML"; fi ;;
            /restarthaproxy)
                if systemctl restart haproxy 2>/dev/null; then send_msg "$CHAT" "${E_OK} <b>HAProxy</b> restarted successfully." "HTML"; else send_msg "$CHAT" "${E_ERR} <b>HAProxy</b> failed to restart." "HTML"; fi ;;
            /restartvps)
                send_msg "$CHAT" "${E_REBOOT} <b>VPS</b> rebooting..." "HTML"
                sleep 2
                reboot ;;
            /genconfig|/config)
                send_msg "$CHAT" "Usage: /config <email>" ;;
            /backup)
                BAK="/root/vpn-backups/xray-$(date +%Y%m%d-%H%M%S).json"
                mkdir -p /root/vpn-backups
                cp /usr/local/etc/xray/config.json "$BAK" 2>/dev/null || true
                curl -s -X POST "${API}/sendDocument" \
                    -F "chat_id=${CHAT}" \
                    -F "document=@${BAK}" >/dev/null 2>&1 || true
                send_msg "$CHAT" "Xray config backup sent." ;;
            /genconfig\ *|/config\ *)
                read -r _ EMAIL <<< "$TEXT"
                if [ -z "${EMAIL:-}" ]; then
                    send_msg "$CHAT" "Usage: /config <email>"
                else
                    if gen-config "$EMAIL" >/tmp/genconfig.out 2>&1; then
                        if [ -f "/root/vpn-configs/${EMAIL}.txt" ]; then
                            CFG=$(cat "/root/vpn-configs/${EMAIL}.txt" 2>/dev/null)
                            ESC=$(printf '%s' "$CFG" | html_escape)
                            send_msg "$CHAT" "<b>${E_CONFIG} Config for $EMAIL</b>
 
<pre>$ESC</pre>
 
Copy each link from the text above." "HTML"
                        else
                            send_msg "$CHAT" "Config generated."
                        fi
                    else
                        send_msg "$CHAT" "${E_ERR} Failed to generate config."
                    fi
                fi
                ;;
            /info)
                OUT=$(vpn-status 2>/dev/null)
                ESC=$(printf '%s' "$OUT" | html_escape)
                send_msg "$CHAT" "<b>${E_STATUS} Status Server</b>

<pre>$ESC</pre>" "HTML" ;;
            /help)
                send_msg "$CHAT" "<b>${E_HELP} VPNKu Bot Help</b>

<b>/status</b>
Shows service status (Xray, HAProxy), server domain, ports &amp; paths used.

<b>/traffic</b>
Shows bandwidth usage (upload/download) per user. Use 'traffic --reset' via CLI to reset counters.

<b>/warpon</b>
Enables Cloudflare WARP as default outbound (traffic exits via Cloudflare).

<b>/warpoff</b>
Disables WARP, reverts to direct connection.

<b>/restartxray</b>
Restarts Xray service (reloads config). Use after adding/removing users if needed.

<b>/restarthaproxy</b>
Restarts HAProxy (reverse proxy). Use if routing/port issues occur.

<b>/restartvps</b>
Reboots the entire VPS. All services will restart.

<b>/add &lt;email&gt; [uuid]</b>
Adds a new user to all protocols/transports (VMess &amp; VLESS x WebSocket, gRPC, HTTPUpgrade) at once. UUID auto-generated if omitted. Account valid for 30 days. Returns the UUID and all share links (vmess/vless for every transport).

<b>/del &lt;email&gt;</b>
Removes a user from all protocols/transports at once.

<b>/users</b>
Lists all users with account expiry dates.

<b>/config &lt;email&gt;</b>
Generates share links (vmess:// / vless://) for a user and sends them as text.

<b>/backup</b>
Creates a backup of the Xray config file and sends it as a document.

<b>/menu</b>
Shows the main menu again.

Tips: Use the menu buttons below for quick access. Only the admin chat ID is allowed." "HTML" ;;
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
                        send_msg "$CHAT" "${E_OK} User added: $EMAIL
UUID: $UUID"
                        gen-config "$EMAIL" >/tmp/genconfig.out 2>&1 || true
                        if [ -f "/root/vpn-configs/${EMAIL}.txt" ]; then
                            CFG=$(cat "/root/vpn-configs/${EMAIL}.txt" 2>/dev/null)
                            ESC=$(printf '%s' "$CFG" | html_escape)
                            send_msg "$CHAT" "<b>${E_CONFIG} Config for $EMAIL</b>

<pre>$ESC</pre>

Copy each link from the text above." "HTML"
                        fi
                    else
                        send_msg "$CHAT" "${E_ERR} Failed to add user: $EMAIL"
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
                        send_msg "$CHAT" "${E_OK} User deleted: $EMAIL"
                    else
                        send_msg "$CHAT" "${E_ERR} Failed to delete user: $EMAIL"
                    fi
                fi
                ;;
            /users|/users\ *|/list|/list\ *)
                RES=$(python3 - 2>/dev/null <<'PY'
import json, datetime
CONFIG="/usr/local/etc/xray/config.json"
try:
    d=json.load(open(CONFIG))
except Exception:
    print("Failed to read Xray config.")
    raise SystemExit
seen={}
for inb in d.get("inbounds", []):
    for c in (inb.get("settings", {}).get("clients") or []):
        e=c.get("email")
        if not e:
            continue
        exp=c.get("expiryTime", 0) or 0
        if e not in seen or exp > seen[e]:
            seen[e]=exp
if not seen:
    print("No users found.")
else:
    lines=["Users (%d):" % len(seen)]
    for e in sorted(seen):
        exp=seen[e]
        if exp:
            try:
                dt=datetime.datetime.fromtimestamp(exp/1000).strftime("%Y-%m-%d")
                lines.append("- %s (exp %s)" % (e, dt))
            except Exception:
                lines.append("- %s" % e)
        else:
            lines.append("- %s" % e)
    out="\n".join(lines)
    if len(out) > 3800:
        out=out[:3800]+"\n... (truncated)"
    print(out)
PY
)
                OUT="${RES:-No users found.}"
                ESC=$(printf '%s' "$OUT" | html_escape)
                send_msg "$CHAT" "<b>${E_USER} User List</b>

<pre>$ESC</pre>" "HTML" ;;
            *)
                # Only reply to non-empty text
                if [ -n "${TEXT:-}" ]; then
                    send_msg "$CHAT" "${E_HELP} Unknown command. Type /start or /help for the command list."
                fi
                ;;
        esac
    done < /tmp/vpnku_updates.txt

    sleep 1
done
