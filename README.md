# VPNKu

Auto-installer for VPN servers based on **Xray-Core + HAProxy** on Debian/Ubuntu VPS.
Supports **VMess** and **VLESS** with three transports: **WebSocket**, **gRPC**, and **HTTPUpgrade**.

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Ports & Routing](#ports--routing)
- [Account Management](#account-management)
- [Transports](#transports)
- [Cloudflare WARP](#cloudflare-warp-optional)
- [Telegram Bot](#telegram-bot-optional)
- [Cloudflare Proxy](#cloudflare-proxy-optional)
- [Monitoring](#monitoring)
- [Version Notes](#version-notes)
- [Important Files](#important-files)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)
- [Notes](#notes)

---

## Features

- Automatic installation of Xray-Core + HAProxy (reverse proxy) + system optimization.
- Self-signed SSL (3650 days) for HAProxy.
- 3 transports per protocol: WebSocket, gRPC (HTTP/2), HTTPUpgrade.
- Unified account management across all protocols/transports (one UUID).
- 30-day account expiry with automatic cleanup.
- Per-user bandwidth monitoring.
- Optional Cloudflare WARP outbound with on/off toggle.
- Optional Telegram bot for remote management.
- Share-link generator (vmess:// / vless://) with custom address/SNI/host.

---

## Project Structure

```
VPNKu/
|-- install.sh              # Main installer
|-- install/
|   |-- xray.sh             # Xray-Core installation & configuration
|   |-- haproxy.sh          # HAProxy installation & configuration
|   `-- optimize.sh         # System optimization
|-- config/
|   |-- xray.json           # Xray configuration template
|   `-- haproxy.cfg         # HAProxy configuration template
|-- scripts/
|   |-- account-add.sh      # Add user (all protocols/transports)
|   |-- account-del.sh      # Delete user (all protocols/transports)
|   |-- account-expire.sh   # Remove expired accounts (30 days)
|   |-- gen-config.sh       # Generate share links (vmess/vless)
|   |-- traffic.sh          # Per-user bandwidth monitoring
|   |-- warp-setup.sh       # Cloudflare WARP setup
|   |-- warp-on.sh          # Enable WARP
|   |-- warp-off.sh         # Disable WARP (direct)
|   |-- status.sh           # Service status
|   |-- setup-telegram-bot.sh # Telegram bot setup
|   |-- update.sh           # Update scripts & bot
|   `-- uninstall.sh        # Uninstall VPNKu
|-- bot/
|   |-- account-add.sh      # Add user (Telegram bot)
|   |-- account-del.sh      # Delete user (Telegram bot)
|   `-- telegram-bot.sh     # Bot polling loop
`-- README.md
```

---

## Requirements

- Fresh Debian/Ubuntu VPS.
- Root access.
- Domain (optional, for SNI/SSL).

---

## Installation

```bash
# Debian
apt update -y && apt upgrade -y && apt dist-upgrade -y && reboot

# Ubuntu
apt-get update && apt-get upgrade -y && apt dist-upgrade -y && update-grub && reboot

# Install VPNKu
cd /root && wget https://raw.githubusercontent.com/Serarinne/VPNKu/main/install.sh && chmod +x install.sh && ./install.sh
```

During installation you will be asked for **Server Name** and **Server Domain**. At the end you may configure the Telegram bot.

---

## Ports & Routing

### Xray (listens on 127.0.0.1)

| Protocol | Transport | Port | Path / ServiceName |
|---|---|---|---|
| VMess | WebSocket | 7001 | `/vmess` |
| VLESS | WebSocket | 7002 | `/vless` |
| VMess | gRPC | 7003 | `vmess-grpc` |
| VLESS | gRPC | 7004 | `vless-grpc` |
| VMess | HTTPUpgrade | 7005 | `/vmess-hu` |
| VLESS | HTTPUpgrade | 7006 | `/vless-hu` |
| API | dokodemo-door | 6969 | (internal) |

### HAProxy (public)

- `:80` and `:443` (SSL termination).
- ALPN: `h2,http/1.1`.
- Path routing: `/vmess`, `/vless`, `/vmess-grpc`, `/vless-grpc`, `/vmess-hu`, `/vless-hu`.
- Other paths -> 404.

---

## Account Management

### CLI

```bash
add-user      # add client to all protocols & transports (input email)
del-user      # delete client from all protocols & transports (choose from list)
gen-config    # generate share links (vmess/vless) for a client
expire-accounts # remove expired accounts (30 days) manually
status-vpn    # show service status, WARP, client count
traffic       # show per-user bandwidth usage (up/down)
traffic --reset # reset usage statistics
warp-setup    # setup Cloudflare WARP (once)
warp-on       # enable WARP
warp-off      # disable WARP (direct)
update-vpn    # update all scripts & bot to latest version
uninstall-vpn # remove VPNKu configuration
```

### Telegram Bot

```bash
bot-add-user <email> [uuid]   # UUID auto-generated if omitted
bot-del-user <email>
```

A single account (email + UUID) is added to **all** inbounds (VMess & VLESS x WebSocket, gRPC, HTTPUpgrade) at once, and removed from all at once.

**Expiry:** Each account is valid for 30 days (31 if created at/after 12:00). Xray rejects expired users automatically (via `expiryTime`), and a daily cron job (`expire-accounts` at 00:00) removes expired entries from the config.

### Bandwidth Monitoring Notes

Xray statistics are kept in memory and reset whenever the Xray service restarts. For periodic reporting, run `traffic` (and optionally `traffic --reset`) via cron, e.g. daily at 23:55, before any planned restart.

---

## Transports

| Transport | Speed | Compatibility | Notes |
|---|---|---|---|
| WebSocket | Medium-High | Very High | Safest for various networks/CDNs |
| gRPC | High (multiplexing) | Medium | Requires HTTP/2; may be blocked by some ISPs |
| HTTPUpgrade | Highest (minimal overhead) | High | Looks like normal HTTP; client must support |

Estimated throughput (1 Gbps link): HTTPUpgrade ~850-920 Mbps, gRPC ~830-910 Mbps, WebSocket ~800-880 Mbps.

---

## Cloudflare WARP (Optional)

Xray includes a **WARP** outbound (WireGuard to Cloudflare) that can be toggled without manual config editing.

### Setup (once, after installation)
```bash
warp-setup
```

### Toggle
```bash
warp-on    # route default traffic through WARP
warp-off   # revert to direct connection
```

---

## Telegram Bot (Optional)

A polling-based Telegram bot is included for remote account management.

### Automatic Setup
During installation you will be asked: `Configure Telegram bot now? (y/N)`. Answer `y` and provide Bot Token and Admin Chat ID.

Or run later:
```bash
setup-telegram-bot
```

### Manual Setup
1. Create a bot via **@BotFather** and get the token.
2. Get your chat ID via **@userinfobot**.
3. Edit `/opt/vpnku-bot/telegram-bot.sh` (set `BOT_TOKEN` and `ADMIN_CHAT_ID`).
4. Start: `systemctl enable --now vpnku-bot`.

### Bot Commands

| Command | Function |
|---|---|
| `/start` | Help + menu |
| `/add <email> [uuid]` | Add user (UUID auto-generated if omitted) |
| `/del <email>` | Delete user |
| `/genconfig <email>` | Generate share links (file) |
| `/backup` | Send Xray config backup (file) |
| `/status` | Service status |
| `/traffic` | Bandwidth usage per user |
| `/warpon` | Enable WARP |
| `/warpoff` | Disable WARP (direct) |
| `/restartxray` | Restart Xray service |
| `/restarthaproxy` | Restart HAProxy service |
| `/restartvps` | Reboot the VPS |

The bot also displays a **reply keyboard menu** (buttons) for quick access.

### Security
- Only the configured admin chat ID is accepted.
- Token file permissions set to 600.
- Bot runs as root (required for management scripts).

---

## Cloudflare Proxy (Optional)

If you put Cloudflare in front of the VPS (orange cloud), apply these settings so all transports work.

### DNS
- Create an **A record** pointing your domain to the VPS IP, with **Proxy status: Proxied (orange cloud)**.

### SSL/TLS
- Mode: **Full (strict)** (recommended) or **Full**.
- Edge Certificates: enable **Always Use HTTPS**.

### Network
- **WebSockets**: On (default). Required for WebSocket & HTTPUpgrade transports.
- **gRPC**: On (under Network -> gRPC). Required for gRPC transport.
- **HTTP/2**: On (default).

### Cloudflare Limitations
- gRPC is supported only on specific plans/paths; if gRPC fails behind Cloudflare, use WebSocket or HTTPUpgrade paths instead, or set the record to **DNS only (grey cloud)** for that subdomain.
- Cloudflare may buffer/stream; for large transfers consider disabling proxy (grey cloud) for the VPN subdomain.

### Example Client Settings (behind Cloudflare)
- Address: your domain (or `support.zoom.us` if using custom address)
- SNI/Host: `support.zoom.us.<your_domain>` (if custom) or your domain
- Path: `/vmess`, `/vless`, `/vmess-hu`, `/vless-hu`
- gRPC serviceName: `vmess-grpc`, `vless-grpc`
- TLS: enabled, port 443

---

## Custom Share Link Address (Optional)

By default, generated share links use:
- **Address**: `support.zoom.us`
- **SNI/Host**: `support.zoom.us.<server_domain>`

To customize, create `/etc/vps-data/gen-config.conf`:
```bash
GEN_ADDR="support.zoom.us"
GEN_SNI="support.zoom.us.yourdomain.com"
GEN_HOST="support.zoom.us.yourdomain.com"
```
Then run `gen-config` again.

---

## Monitoring

```bash
traffic         # show per-user upload/download (MB)
traffic --reset # reset counters
status-vpn      # service status, WARP, client count
```

---

## Version Notes

- **Xray-Core**: follows the latest release (via official XTLS installer).
- **HAProxy**: uses the version from the OS repository (stable, receives security patches from OS maintainers).

To use the latest HAProxy version, add the official repository before running `install.sh`:

```bash
# Ubuntu
add-apt-repository -y ppa:vbernat/haproxy-3.0

# Debian
curl -fsSL https://haproxy.debian.net/bernat.debian.org.gpg | gpg --dearmor -o /usr/share/keyrings/haproxy.debian.net.gpg
echo "deb [signed-by=/usr/share/keyrings/haproxy.debian.net.gpg] http://haproxy.debian.net $(lsb_release -cs)-backports-2.8 main" > /etc/apt/sources.list.d/haproxy.list
```

Then run `apt update` and `install.sh`.

---

## Important Files

- Xray config: `/usr/local/etc/xray/config.json`
- HAProxy config: `/etc/haproxy/haproxy.cfg`
- Certificates: `/etc/vps-data/cert.crt`, `/etc/vps-data/cert.key`, `/etc/vps-data/haproxy.pem`
- Server data: `/etc/vps-data/name`, `/etc/vps-data/domain`
- Gen-config: `/etc/vps-data/gen-config.conf`
- Traffic log: `/var/log/vpnku-expire.log`
- Backups: `/root/vpn-backups/`

---

## Troubleshooting

- **Xray fails to start**: run `xray run -test -config /usr/local/etc/xray/config.json` to see the error. Restore from `/usr/local/etc/xray/config.json.bak` if needed.
- **HAProxy 502/503**: check `haproxy -c -f /etc/haproxy/haproxy.cfg` and `systemctl status haproxy`. Ensure Xray inbounds are listening (`ss -tlnp`).
- **gRPC fails behind Cloudflare**: switch to WebSocket/HTTPUpgrade paths, or set the DNS record to grey cloud (DNS only).
- **Bot not responding**: check `systemctl status vpnku-bot` and `/opt/vpnku-bot/telegram-bot.sh` (token/chat ID).
- **No bandwidth data**: Xray stats reset on restart; run `traffic` after some usage.

---

## Uninstall

```bash
uninstall-vpn
```

Removes configuration and commands. Xray/HAProxy binaries remain; remove manually if needed.

---

## Notes

- All scripts must be run as **root**.
- SSL certificate is **self-signed** (not Let's Encrypt).
- Project intended for personal/learning use; ensure compliance with laws and VPS provider TOS.