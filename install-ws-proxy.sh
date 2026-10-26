#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

echo "=> Memulai Instalasi & Konfigurasi WebSocket Proxy (Python)..."
wget --inet4-only -q -O /usr/local/bin/ws-proxy "https://raw.githubusercontent.com/Serarinne/VPNKu/main/ws-proxy" >/dev/null 2>&1 && chmod +x /usr/local/bin/ws-proxy
cat > /etc/systemd/system/ws-proxy.service << END
[Unit]
Description=Websocket Tunnel
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python3 -O /usr/local/bin/ws-proxy
Restart=on-failure

[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload >/dev/null 2>&1
systemctl enable ws-proxy >/dev/null 2>&1
systemctl start ws-proxy >/dev/null 2>&1
systemctl restart ws-proxy >/dev/null 2>&1
echo ""
echo "✅ Instalasi & Konfigurasi WebSocket Proxy (Python) Selesai!"
