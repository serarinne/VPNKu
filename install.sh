#!/bin/bash
timedatectl set-timezone Asia/Jakarta

if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|           Instalasi Package           |"
echo -e "-----------------------------------------"
sleep 1
apt-get remove --purge nginx* -y
apt-get remove --purge nginx-common* -y
apt-get remove --purge nginx-full* -y
apt-get remove --purge dropbear* -y
apt-get remove --purge stunnel4* -y
apt-get remove --purge apache2* -y
apt-get remove --purge ufw* -y
apt-get remove --purge firewalld* -y
apt-get remove --purge exim4* -y
apt autoremove -y

apt update -y

apt install sudo dpkg psmisc socat jq ruby wondershaper python3 tmux nmap bzip2 gzip coreutils screen rsyslog iftop htop zip unzip wget vim net-tools curl nano sed gnupg gnupg1 bc apt-transport-https build-essential gcc g++ automake make autoconf perl m4 dos2unix libreadline-dev zlib1g-dev libssl-dev dirmngr libxml-parser-perl neofetch git lsof iptables iptables-persistent screenfetch openssl easy-rsa fail2ban vnstat libsqlite3-dev cron bash-completion ntpdate xz-utils gnupg2 dnsutils lsb-release chrony lolcat -y

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|             Setup Server              |"
echo -e "-----------------------------------------"
sleep 1
echo -e ""
read -rp "Server Name        : " SERVER_NAME
read -rp "Server Domain      : " SERVER_DOMAIN
mkdir -p /etc/vps-data
rm -f /etc/vps-data/name
rm -f /etc/vps-data/domain
echo $SERVER_NAME > /etc/vps-data/name
echo $SERVER_DOMAIN > /etc/vps-data/domain

#curl https://get.acme.sh | sh -s email=admin@seras.my.id

#/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
#/root/.acme.sh/acme.sh --issue -d $SERVER_DOMAIN --standalone -k ec-256
#/root/.acme.sh/acme.sh --install-cert -d $SERVER_DOMAIN --fullchain-file /etc/vps-data/cert.crt --key-file /etc/vps-data/cert.key --ecc

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/vps-data/cert.key -out /etc/vps-data/cert.crt -subj "/C=ID/ST=Jawa Barat/L=Bogor/O=Serarinne/OU=VPN/CN=${SERVER_DOMAIN}"

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|                OpenSSH                |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/install-openssh.sh >/dev/null 2>&1 && chmod +x install-openssh.sh && ./install-openssh.sh
rm install-openssh.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|               Dropbear                |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/install-dropbear.sh >/dev/null 2>&1 && chmod +x install-dropbear.sh && ./install-dropbear.sh
rm install-dropbear.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|                STunnel                |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/install-stunnel.sh >/dev/null 2>&1 && chmod +x install-stunnel.sh && ./install-stunnel.sh
rm install-stunnel.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|       WebSocket Proxy (Python)        |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/install-ws-proxy.sh >/dev/null 2>&1 && chmod +x install-ws-proxy.sh && ./install-ws-proxy.sh
rm install-ws-proxy.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|                BadVPN                 |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/install-badvpn.sh >/dev/null 2>&1 && chmod +x install-badvpn.sh && ./install-badvpn.sh
rm install-badvpn.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|              XRAY-Core                |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/install-xray.sh >/dev/null 2>&1 && chmod +x install-xray.sh && ./install-xray.sh
rm install-xray.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|                Nginx                  |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/install-nginx.sh >/dev/null 2>&1 && chmod +x install-nginx.sh && ./install-nginx.sh
rm install-nginx.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|               Optimasi                |"
echo -e "-----------------------------------------"
sleep 1
wget -q --inet4-only https://raw.githubusercontent.com/Serarinne/VPNKu/main/optimasi-sistem.sh >/dev/null 2>&1 && chmod +x optimasi-sistem.sh && ./optimasi-sistem.sh
rm optimasi-sistem.sh

sleep 2
clear
echo -e "-----------------------------------------"
echo -e "|          Unduh File Perintah          |"
echo -e "-----------------------------------------"
echo ""
sleep 1
echo "=> Tambah Akun SSH"
wget --inet4-only -O /usr/bin/tambah-ssh -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bash/tambah-ssh.sh >/dev/null 2>&1 && chmod +x /usr/bin/tambah-ssh
echo "=> Hapus Akun SSH"
wget --inet4-only -O /usr/bin/hapus-ssh -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bash/hapus-ssh.sh >/dev/null 2>&1 && chmod +x /usr/bin/hapus-ssh
echo "=> Tambah Akun VMESS"
wget --inet4-only -O /usr/bin/tambah-vmess -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bash/tambah-vmess.sh >/dev/null 2>&1 && chmod +x /usr/bin/tambah-vmess
echo "=> Hapus Akun VMESS"
wget --inet4-only -O /usr/bin/hapus-vmess -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bash/hapus-vmess.sh >/dev/null 2>&1 && chmod +x /usr/bin/hapus-vmess

echo "=> Bot Tambah Akun SSH"
wget --inet4-only -O /usr/bin/bot-tambah-ssh -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bot/bot-tambah-ssh.sh >/dev/null 2>&1 && chmod +x /usr/bin/bot-tambah-ssh
echo "=> Bot Hapus Akun SSH"
wget --inet4-only -O /usr/bin/bot-hapus-ssh -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bot/bot-hapus-ssh.sh >/dev/null 2>&1 && chmod +x /usr/bin/bot-hapus-ssh
echo "=> Bot Tambah Akun VMESS"
wget --inet4-only -O /usr/bin/bot-tambah-vmess -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bot/bot-tambah-vmess.sh >/dev/null 2>&1 && chmod +x /usr/bin/bot-tambah-vmess
echo "=> Bot Hapus Akun VMESS"
wget --inet4-only -O /usr/bin/bot-hapus-vmess -q https://raw.githubusercontent.com/Serarinne/VPNKu/main/bot/bot-hapus-vmess.sh >/dev/null 2>&1 && chmod +x /usr/bin/bot-hapus-vmess

read -p "$(echo -e "Tekan [Enter] untuk Reboot")"
rm install.sh
reboot
