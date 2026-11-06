#!/bin/bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

timedatectl set-timezone Asia/Jakarta 2>/dev/null || true

# Detect OS (Debian / Ubuntu) for package differences
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "[ERR] /etc/os-release not found; unsupported system." 1>&2
    exit 1
fi

case "${ID:-}" in
    debian|ubuntu) ;;
    *)
        echo "[ERR] Unsupported OS: ${ID:-unknown}. Only Debian and Ubuntu are supported." 1>&2
        exit 1
        ;;
esac

# Helper: only keep packages that actually have an installable candidate
pkg_available() {
    apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -qv '(none)'
}

# Base packages available on both Debian and Ubuntu
PKGS=(
    sudo dpkg psmisc socat jq ruby python3 tmux nmap bzip2 gzip
    coreutils screen rsyslog iftop htop zip unzip wget vim net-tools curl nano
    sed gnupg bc build-essential gcc g++ automake make autoconf perl m4 dos2unix
    libreadline-dev zlib1g-dev libssl-dev dirmngr libxml-parser-perl git lsof
    iptables iptables-persistent screenfetch openssl easy-rsa fail2ban vnstat
    libsqlite3-dev cron bash-completion xz-utils gnupg2 dnsutils lsb-release
    chrony lolcat
)

# Optional/legacy packages resolved after `apt update` (see step 2).
OPTIONAL_PKGS=(neofetch gnupg1 apt-transport-https ntpdate ntpsec-ntpdate wondershaper)

# ---------- Checkpoint / resume support ----------
CHECKPOINT_FILE="/etc/vps-data/install.checkpoint"
mkdir -p /etc/vps-data

# Allow manual reset: ./install.sh --reset
if [ "${1:-}" = "--reset" ]; then
    rm -f "$CHECKPOINT_FILE"
    echo "[OK] Installation checkpoint reset."
    exit 0
fi

is_done() {
    [ -f "$CHECKPOINT_FILE" ] && grep -qx "$1" "$CHECKPOINT_FILE"
}

mark_done() {
    touch "$CHECKPOINT_FILE"
    if ! grep -qx "$1" "$CHECKPOINT_FILE" 2>/dev/null; then
        echo "$1" >> "$CHECKPOINT_FILE"
    fi
}

skip_step() {
    echo "[SKIP] Step $1 already completed, skipping."
}

fetch() {
  mkdir -p "$(dirname "$2")"
  local url="$1"
  if [[ "$url" == *\?* ]]; then
    url="${url}&_=$(date +%s%N)"
  else
    url="${url}?_=$(date +%s%N)"
  fi
  if ! wget -q --inet4-only --header="Cache-Control: no-cache, no-store, must-revalidate" --header="Pragma: no-cache" "$url" -O "$2"; then
    echo "[ERR] Failed to download $1"
    wget --inet4-only --header="Cache-Control: no-cache, no-store, must-revalidate" --header="Pragma: no-cache" "$url" -O "$2" || true
    exit 1
  fi
}

step() { echo ""; echo "[INFO] ($1/$2) $3"; }

TOTAL=8

if [ -f "$CHECKPOINT_FILE" ]; then
    echo "[INFO] Checkpoint found. Completed steps: $(tr '\n' ' ' < "$CHECKPOINT_FILE")"
    echo "[INFO] Resuming installation; completed steps will be skipped."
fi

# Step 1
if is_done 1; then
    skip_step 1
    SERVER_NAME="$(cat /etc/vps-data/name)"
    SERVER_DOMAIN="$(cat /etc/vps-data/domain)"
else
    step 1 $TOTAL "Server setup"
    read -rp "Server Name        : " SERVER_NAME
    read -rp "Server Domain      : " SERVER_DOMAIN
    mkdir -p /etc/vps-data
    rm -f /etc/vps-data/name /etc/vps-data/domain
    echo "$SERVER_NAME" > /etc/vps-data/name
    echo "$SERVER_DOMAIN" > /etc/vps-data/domain

    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout /etc/vps-data/cert.key -out /etc/vps-data/cert.crt \
      -subj "/C=ID/ST=Jawa Barat/L=Bogor/O=Serarinne/OU=VPN/CN=${SERVER_DOMAIN}"

    mark_done 1
fi

# Step 2
if is_done 2; then
    skip_step 2
else
    step 2 $TOTAL "Installing packages"
    apt-get remove --purge nginx* nginx-common* nginx-full* apache2* ufw* firewalld* exim4* -y >/dev/null 2>&1 || true
    apt autoremove -y >/dev/null 2>&1 || true
    apt update -y

    # Resolve optional/legacy packages now that apt lists are fresh.
    if [ "${ID}" = "ubuntu" ]; then
        for opt in neofetch gnupg1 apt-transport-https ntpdate; do
            if pkg_available "$opt"; then
                PKGS+=("$opt")
            fi
        done
    fi
    if [ "${ID}" = "debian" ]; then
        for opt in "${OPTIONAL_PKGS[@]}"; do
            if pkg_available "$opt"; then
                PKGS+=("$opt")
            fi
        done
    fi

    # Drop any package without an installable candidate (e.g. removed in newer Debian).
    FILTERED=()
    for p in "${PKGS[@]}"; do
        if pkg_available "$p"; then
            FILTERED+=("$p")
        else
            echo "[WARN] Skipping unavailable package: $p"
        fi
    done
    PKGS=("${FILTERED[@]}")

    DEBIAN_FRONTEND=noninteractive apt install -y "${PKGS[@]}"

    mark_done 2
fi

# Step 3
if is_done 3; then
    skip_step 3
else
    step 3 $TOTAL "Xray-Core"
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/install/xray.sh" "install/xray.sh"
    chmod +x install/xray.sh && ./install/xray.sh
    rm -f install/xray.sh
    mark_done 3
fi

# Step 4
if is_done 4; then
    skip_step 4
else
    step 4 $TOTAL "HAProxy"
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/install/haproxy.sh" "install/haproxy.sh"
    chmod +x install/haproxy.sh && ./install/haproxy.sh
    rm -f install/haproxy.sh
    mark_done 4
fi

# Step 5
if is_done 5; then
    skip_step 5
else
    step 5 $TOTAL "System optimization"
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/install/optimize.sh" "install/optimize.sh"
    chmod +x install/optimize.sh && ./install/optimize.sh
    rm -f install/optimize.sh
    mark_done 5
fi

# Step 6
if is_done 6; then
    skip_step 6
else
    step 6 $TOTAL "Downloading commands"
    mkdir -p /usr/bin
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/account-add.sh" "/usr/bin/add-user" && chmod +x /usr/bin/add-user
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/account-del.sh" "/usr/bin/del-user" && chmod +x /usr/bin/del-user
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/warp-setup.sh" "/usr/bin/warp-setup" && chmod +x /usr/bin/warp-setup
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/warp-on.sh" "/usr/bin/warp-on" && chmod +x /usr/bin/warp-on
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/warp-off.sh" "/usr/bin/warp-off" && chmod +x /usr/bin/warp-off
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/status.sh" "/usr/bin/vpn-status" && chmod +x /usr/bin/vpn-status
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/check-optimize.sh" "/usr/bin/check-optimize" && chmod +x /usr/bin/check-optimize
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/gaming-mode.sh" "/usr/bin/gaming-mode" && chmod +x /usr/bin/gaming-mode
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/uninstall.sh" "/usr/bin/uninstall-vpn" && chmod +x /usr/bin/uninstall-vpn
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/traffic.sh" "/usr/bin/traffic" && chmod +x /usr/bin/traffic
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/account-expire.sh" "/usr/bin/expire-accounts" && chmod +x /usr/bin/expire-accounts
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/gen-config.sh" "/usr/bin/gen-config" && chmod +x /usr/bin/gen-config
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/setup-telegram-bot.sh" "/usr/bin/setup-telegram-bot" && chmod +x /usr/bin/setup-telegram-bot
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/scripts/update.sh" "/usr/bin/update-vpn" && chmod +x /usr/bin/update-vpn
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/bot/account-add.sh" "/usr/bin/bot-add-user" && chmod +x /usr/bin/bot-add-user
    fetch "https://raw.githubusercontent.com/serarinne/VPNKu/main/bot/account-del.sh" "/usr/bin/bot-del-user" && chmod +x /usr/bin/bot-del-user

    # Daily expiry cleanup at 00:00
    (crontab -l 2>/dev/null; echo "0 0 * * * /usr/bin/expire-accounts") | sort -u | crontab -

    mark_done 6
fi

# Step 7
if is_done 7; then
    skip_step 7
else
    step 7 $TOTAL "Firewall"
    # Use iptables directly (ufw conflicts with iptables-persistent)
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -P INPUT ACCEPT
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -p tcp --dport 443 -j ACCEPT
    iptables -P INPUT DROP
    mkdir -p /etc/iptables
    iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    systemctl enable netfilter-persistent >/dev/null 2>&1 || true

    mark_done 7
fi

# Step 8
if is_done 8; then
    skip_step 8
else
    step 8 $TOTAL "Done"
    echo "[OK] Installation complete. Reboot to apply."
    echo ""
    read -rp "Configure Telegram bot now? (y/N): " CFG_BOT
    if [ "$CFG_BOT" = "y" ] || [ "$CFG_BOT" = "Y" ]; then
        setup-telegram-bot
    fi

    mark_done 8
fi

read -rp "Press [Enter] to Reboot"
rm -f "$CHECKPOINT_FILE"
rm -f install.sh
reboot