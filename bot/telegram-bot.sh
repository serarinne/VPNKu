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
    if [ -n "$mode" ]; then
        curl -s -X POST "${API}/sendMessage" \
            -d "chat_id=${chat_id}" \
            --data-urlencode "text=${text}" \
            --data-urlencode "parse_mode=${mode}" >/dev/null 2>&1 || true
    else
        curl -s -X POST "${API}/sendMessage" \
            -d "chat_id=${chat_id}" \
            --data-urlencode "text=${text}" >/dev/null 2>&1 || true
    fi
}

send_menu() {
    local chat_id="$1"; local text="$2"
    local kb='{"keyboard":[["/status","/traffic"],["/warpon","/warpoff"],["/restartxray","/restarthaproxy"],["/restartvps"],["/add","/del","/users"],["/genconfig"],["/backup"],["/help"],["/start"]],"resize_keyboard":true,"one_time_keyboard":false}'
    [ -z "$chat_id" ] && return 0
    curl -s -X POST "${API}/sendMessage" \
        -d "chat_id=${chat_id}" \
        --data-urlencode "text=${text}" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "reply_markup=${kb}" >/dev/null 2>&1 || true
}

log "Bot started (admin=${ADMIN_CHAT_ID})"

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

        case "$TEXT" in
            /menu)
                TEXT="/start" ;;
        esac

        case "$TEXT" in
            /start)
                send_menu "$CHAT" "<b>VPNKu Bot</b> - Panel Manajemen VPN

Selamat datang! Gunakan tombol menu di bawah atau ketik perintah langsung.

<b>Daftar Perintah:</b>
/status - Status layanan &amp; domain
/traffic - Pemakaian bandwidth per user
/warpon - Aktifkan Cloudflare WARP
/warpoff - Nonaktifkan WARP (direct)
/restartxray - Restart layanan Xray
/restarthaproxy - Restart layanan HAProxy
/restartvps - Reboot VPS
/add &lt;email&gt; [uuid] - Tambah user baru
/del &lt;email&gt; - Hapus user
/users - Daftar user &amp; masa aktif
/genconfig &lt;email&gt; - Generate share link
/backup - Backup config Xray
/help - Penjelasan lengkap tiap fitur
/menu - Tampilkan ulang menu utama

Ketik /help untuk penjelasan detail." ;;
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
            /genconfig|/config)
                send_msg "$CHAT" "Usage: /genconfig <email>" ;;
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
                send_msg "$CHAT" "$(vpn-status 2>/dev/null)" ;;
            /help)
                send_msg "$CHAT" "<b>Bantuan VPNKu Bot</b>

<b>/status</b>
Menampilkan status layanan (Xray, HAProxy), domain server, port &amp; path yang digunakan.

<b>/traffic</b>
Menampilkan pemakaian bandwidth (upload/download) per user. Gunakan 'traffic --reset' via CLI untuk reset counter.

<b>/warpon</b>
Mengaktifkan Cloudflare WARP sebagai outbound default (traffic keluar lewat Cloudflare).

<b>/warpoff</b>
Menonaktifkan WARP, kembali ke koneksi langsung (direct).

<b>/restartxray</b>
Me-restart layanan Xray (reload config). Gunakan setelah menambah/menghapus user jika perlu.

<b>/restarthaproxy</b>
Me-restart HAProxy (reverse proxy). Gunakan jika ada masalah routing/port.

<b>/restartvps</b>
Me-reboot seluruh VPS. Semua layanan akan restart.

<b>/add &lt;email&gt; [uuid]</b>
Menambah user baru ke semua protokol/transport (VMess &amp; VLESS x WebSocket, gRPC, HTTPUpgrade) sekaligus. UUID otomatis dibuat jika tidak diisi. Masa aktif 30 hari.

<b>/del &lt;email&gt;</b>
Menghapus user dari semua protokol/transport sekaligus.

<b>/users</b>
Menampilkan daftar semua user beserta tanggal kadaluarsa akun.

<b>/genconfig &lt;email&gt;</b>
Membuat file share link (vmess:// / vless://) untuk user dan mengirimkannya sebagai file.

<b>/backup</b>
Membuat backup file config Xray dan mengirimkannya sebagai dokumen.

<b>/menu</b>
Menampilkan ulang menu utama.

Tips: Gunakan tombol menu di bawah untuk akses cepat. Hanya chat ID admin yang diizinkan." "HTML" ;;
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
                send_msg "$CHAT" "${RES:-No users found.}" ;;
            *)
                # Only reply to non-empty text
                if [ -n "${TEXT:-}" ]; then
                    send_msg "$CHAT" "Perintah tidak dikenal. Ketik /start atau /help untuk daftar perintah."
                fi
                ;;
        esac
    done < /tmp/vpnku_updates.txt

    sleep 1
done
