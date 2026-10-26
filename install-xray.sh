#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

DOMAIN=$(cat /etc/vps-data/domain)

echo "=> Memulai Instalasi & Konfigurasi XRAY-Core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install > /dev/null 2>&1

mkdir -p /var/log/xray
chown www-data:www-data /var/log/xray
chmod 755 /var/log/xray
touch /var/log/xray/access.log /var/log/xray/error.log

cat <<EOF > /usr/local/etc/xray/config.json
{
    "log": {
        "access": "none",
        "error": "none",
        "loglevel": "info"
    },
    "inbounds": [
        {
            "listen": "127.0.0.1",
            "port": 6969,
            "protocol": "dokodemo-door",
            "settings": {"address": "127.0.0.1"},
            "tag": "API-Inbound"
        },
        {
            "listen": "127.0.0.1",
            "port": 7001,
            "protocol": "vmess",
            "settings": {
                "clients": [
{"id": "60d9785f-0e59-4988-aee1-322351b4de7f", "alterId": 0, "level": 0, "security": "auto", "email": "Admin-WS"}
#USER_ACCOUNT
                ]
            },
            "streamSettings": {
                "network": "ws",
                "wsSettings": {
                    "path": "/vmess"
                }
            },
            "tag": "Vmess-Connection"
        },
        {
            "listen": "127.0.0.1",
            "port": 7002,
            "protocol": "trojan",
            "settings": {
                "clients": [
                    {"password": "Admin-GRPC", "level": 0, "email": "Admin-Trojan-GRPC"}
                    #USER_ACCOUNT
                ]
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "trojan-grpc"
                }
            },
            "tag": "Trojan-GRPC-Connection"
        },
        {
            "listen": "127.0.0.1",
            "port": 7003,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {"id": "60d9785f-0e59-4988-aee1-322351b4de7f", "level": 0, "email": "Admin-VLESS-GRPC"}
                    #USER_ACCOUNT
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "grpc",
                "grpcSettings": {
                    "serviceName": "vless-grpc"
                }
            },
            "tag": "VLESS-GRPC-Connection"
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "Direct-Connection"
        },
        {
            "protocol": "blackhole",
            "tag": "Blackhole"
        }
    ],
    "routing": {
        "domainStrategy": "AsIs",
        "domainMatcher": "hybrid",
        "rules": [
            {
                "domainMatcher": "hybrid",
                "type": "field",
                "protocol": [
                    "http",
                    "tls"
                ],
                "outboundTag": "Direct-Connection"
            },
            {
                "type": "field",
                "domain": [
                    "ext:geosite.dat:category-ads-all"
                ],
                "outboundTag": "Blackhole"
            },
            {
                "type": "field",
                "protocol": [
                    "bittorrent"
                ],
                "outboundTag": "Blackhole"
            },
            {
                "type": "field",
                "inboundTag": ["API-Inbound"],
                "outboundTag": "API-Connection"
            }
        ]
    },
    "api": {
        "tag": "API-Connection",
        "services": [
            "HandlerService",
            "LoggerService",
            "StatsService"
        ]
    },
    "policy": {
        "levels": {
            "0": {
                "statsUserDownlink": true,
                "statsUserUplink": true,
                "statsUserOnline": true
            }
        },
        "system": {
            "statsInboundUplink": true,
            "statsInboundDownlink": true,
            "statsOutboundUplink": true,
            "statsOutboundDownlink": true
        }
    },
    "stats": {}
}
EOF

systemctl daemon-reload >/dev/null 2>&1
systemctl enable xray >/dev/null 2>&1
systemctl restart xray >/dev/null 2>&1
echo ""
echo "✅ Instalasi & Konfigurasi XRAY-Core Selesai!"
