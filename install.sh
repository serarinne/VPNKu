#!/bin/bash
set -euo pipefail
timedatectl set-timezone Asia/Jakarta

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

step() { echo ""; echo "[INFO] ($1/$2) $3"; }

TOTAL=8
step 1 $TOTAL "Installing packages"
apt-get remove --purge nginx* nginx-common* nginx-full* apache2* ufw* firewalld* exim4* -y >/dev/null 2>&1 || true
apt autoremove -y >/dev/null 2>&1 || true
apt update -y
apt install -y sudo dpkg psmisc socat jq ruby wondershaper python3 tmux nmap bzip2 gzip coreutils screen rsyslog iftop htop zip unzip wget vim net-tools curl nano sed gnupg gnupg1 bc apt-transport-https build-essential gcc g++ automake make autoconf perl m4 dos2unix libreadline-dev zlib1g-dev libssl-dev dirmngr libxml-parser-perl neofetch git lsof iptables iptables-persistent screenfetch openssl easy-rsa fail2ban vnstat libsqlite3-dev cron bash-completion ntpdate xz-utils gnupg2 dnsutils lsb-release chrony lolcat ufw

step 2 $TOTAL "Server setup"
read -rp "Server Name        : " SERVER_NAME
read -rp "Server Domain      : " SERVER_DOMAIN
mkdir -p /etc/vps-data
rm -f /etc/vps-data/name /etc/vps-data/domain
echo "$SERVER_NAME" > /etc/vps-data/name
echo "$SERVER_DOMAIN" > /etc/vps-data/domain

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout /etc/vps-data/cert.key -out /etc/vps-data/cert.crt \
  -subj "/C=ID/ST=Jawa Barat/L=Bogor/O=Serarinne/OU=VPN/CN=${SERVER_DOMAIN}"

fetch() {
  if ! wget -q --inet4-only "$1" -O "$2"; then
    echo "[ERR] Failed to download $1"
    exit 1
  fi
}

step 3 $TOTAL "Xray-Core"
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/install/xray.sh" "install/xray.sh"
chmod +x install/xray.sh && ./install/xray.sh
rm -f install/xray.sh

step 4 $TOTAL "HAProxy"
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/install/haproxy.sh" "install/haproxy.sh"
chmod +x install/haproxy.sh && ./install/haproxy.sh
rm -f install/haproxy.sh

step 5 $TOTAL "System optimization"
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/install/optimize.sh" "install/optimize.sh"
chmod +x install/optimize.sh && ./install/optimize.sh
rm -f install/optimize.sh

step 6 $TOTAL "Downloading commands"
mkdir -p /usr/bin
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/account-add.sh" "/usr/bin/add-user" && chmod +x /usr/bin/add-user
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/account-del.sh" "/usr/bin/del-user" && chmod +x /usr/bin/del-user
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/warp-setup.sh" "/usr/bin/warp-setup" && chmod +x /usr/bin/warp-setup
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/warp-on.sh" "/usr/bin/warp-on" && chmod +x /usr/bin/warp-on
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/warp-off.sh" "/usr/bin/warp-off" && chmod +x /usr/bin/warp-off
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/status.sh" "/usr/bin/vpn-status" && chmod +x /usr/bin/vpn-status
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/uninstall.sh" "/usr/bin/uninstall-vpn" && chmod +x /usr/bin/uninstall-vpn
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/traffic.sh" "/usr/bin/traffic" && chmod +x /usr/bin/traffic
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/account-expire.sh" "/usr/bin/expire-accounts" && chmod +x /usr/bin/expire-accounts
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/gen-config.sh" "/usr/bin/gen-config" && chmod +x /usr/bin/gen-config
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/setup-telegram-bot.sh" "/usr/bin/setup-telegram-bot" && chmod +x /usr/bin/setup-telegram-bot
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/scripts/update.sh" "/usr/bin/update-vpn" && chmod +x /usr/bin/update-vpn
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/bot/account-add.sh" "/usr/bin/bot-add-user" && chmod +x /usr/bin/bot-add-user
fetch "https://raw.githubusercontent.com/Serarinne/VPNKu/main/bot/account-del.sh" "/usr/bin/bot-del-user" && chmod +x /usr/bin/bot-del-user

# Daily expiry cleanup at 00:00
(crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/expire-accounts") | sort -u | crontab -

step 7 $TOTAL "Firewall"
ufw --force reset >/dev/null 2>&1 || true
ufw default deny incoming >/dev/null 2>&1 || true
ufw default allow outgoing >/dev/null 2>&1 || true
ufw allow 22/tcp >/dev/null 2>&1 || true
ufw allow 80/tcp >/dev/null 2>&1 || true
ufw allow 443/tcp >/dev/null 2>&1 || true
ufw --force enable >/dev/null 2>&1 || true

step 8 $TOTAL "Done"
echo "[OK] Installation complete. Reboot to apply."
echo ""
read -rp "Configure Telegram bot now? (y/N): " CFG_BOT
if [ "$CFG_BOT" = "y" ] || [ "$CFG_BOT" = "Y" ]; then
    setup-telegram-bot
fi

read -rp "Press [Enter] to Reboot"
rm -f install.sh
reboot
