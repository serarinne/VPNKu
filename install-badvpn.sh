#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root"
   exit 1
fi

PORTS=(7300 7200 7100)

echo "=> Memulai Instalasi & Konfigurasi BadVPN UDP Gateway..."
wget --inet4-only -q -O /usr/local/bin/badvpn-udpgw "https://raw.githubusercontent.com/Serarinne/VPNKu/main/badvpn" >/dev/null 2>&1 && chmod +x /usr/local/bin/badvpn-udpgw

cat <<EOF > /etc/systemd/system/badvpn-udpgw@.service
[Unit]
Description=BadVPN UDP Gateway for Port %I
After=network.target

[Service]
# %I adalah placeholder untuk nomor port yang dilewatkan ke service
# Contoh: badvpn-udpgw@7300 akan menjalankan perintah dengan port 7300
# Ganti 127.0.0.1 dengan 0.0.0.0 jika Anda ingin bisa diakses dari IP publik secara langsung
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:%I --max-clients 1000
Restart=on-failure
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload >/dev/null 2>&1

for PORT in "${PORTS[@]}"; do
  systemctl enable "badvpn-udpgw@${PORT}" >/dev/null 2>&1
  systemctl start "badvpn-udpgw@${PORT}" >/dev/null 2>&1
  systemctl restart "badvpn-udpgw@${PORT}" >/dev/null 2>&1
done

echo ""
echo "✅ Instalasi & Konfigurasi BadVPN UDP Gateway Selesai!"
