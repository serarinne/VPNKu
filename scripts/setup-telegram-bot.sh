#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

BOT_DIR="/opt/vpnku-bot"
mkdir -p "$BOT_DIR"
cp /root/VPNKu/bot/telegram-bot.sh "$BOT_DIR/telegram-bot.sh" 2>/dev/null || \
  wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/bot/telegram-bot.sh -O "$BOT_DIR/telegram-bot.sh"
chmod +x "$BOT_DIR/telegram-bot.sh"

read -rp "Telegram Bot Token: " BOT_TOKEN
read -rp "Admin Chat ID: " ADMIN_CHAT_ID

if [ -z "$BOT_TOKEN" ] || [ -z "$ADMIN_CHAT_ID" ]; then
    echo "[ERR] Token and Chat ID cannot be empty."
    exit 1
fi

sed -i "s/^BOT_TOKEN=.*/BOT_TOKEN=\"${BOT_TOKEN}\"/" "$BOT_DIR/telegram-bot.sh"
sed -i "s/^ADMIN_CHAT_ID=.*/ADMIN_CHAT_ID=\"${ADMIN_CHAT_ID}\"/" "$BOT_DIR/telegram-bot.sh"
chmod 600 "$BOT_DIR/telegram-bot.sh"

cat > /etc/systemd/system/vpnku-bot.service <<EOF
[Unit]
Description=VPNKu Telegram Bot
After=network.target

[Service]
Type=simple
ExecStart=${BOT_DIR}/telegram-bot.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpnku-bot
systemctl restart vpnku-bot
echo "[OK] Telegram bot installed and started."