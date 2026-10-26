#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

echo "=> Memulai Instalasi & Konfigurasi STunnel4..."
apt install stunnel4 -y >/dev/null 2>&1
cat > /etc/stunnel/stunnel4.conf <<-END
cert = /etc/vps-data/cert.crt
key = /etc/vps-data/cert.key
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1

[dropbear]
accept = 447
connect = 127.0.0.1:109

[openssh]
accept = 777
connect = 127.0.0.1:22
END

rm -fr /etc/systemd/system/stunnel4.service
cat > /etc/systemd/system/stunnel4.service << END
[Unit]
Description=Stunnel4 Service
Documentation=https://stunnel.org
After=syslog.target network-online.target

[Service]
ExecStart=stunnel4 /etc/stunnel/stunnel4.conf
Type=forking

[Install]
WantedBy=multi-user.target
END
systemctl daemon-reload >/dev/null 2>&1
systemctl enable stunnel4 >/dev/null 2>&1
systemctl start stunnel4 >/dev/null 2>&1
systemctl restart stunnel4 >/dev/null 2>&1
echo ""
echo "✅ Instalasi & Konfigurasi STunnel4 Selesai!"