#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

echo "=> Memulai Instalasi & Konfigurasi Dropbear Custom..."

# Mengunduh dan mengompilasi Dropbear dari source
wget --inet4-only http://matt.ucc.asn.au/dropbear/releases/dropbear-2019.78.tar.bz2 >/dev/null 2>&1
tar -xvf dropbear-2019.78.tar.bz2
cd dropbear-2019.78
./configure
make
make install

# 1. PERBAIKAN: Membuat direktori penyimpanan key sebelum eksekusi dropbearkey
mkdir -p /etc/dropbear/

# Membuat host key untuk Dropbear
dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
dropbearkey -t ecdsa -f /etc/dropbear/dropbear_ecdsa_host_key
dropbearkey -t ed25519 -f /etc/dropbear/dropbear_ed25519_host_key

# Mengatur permissions key agar aman (wajib bagi OpenSSH/Dropbear)
chmod 600 /etc/dropbear/dropbear_*_host_key
chown root:root /etc/dropbear/dropbear_*_host_key

# 2. PERBAIKAN: Konfigurasi file /etc/default/dropbear dihapus 
# (Karena hasil kompilasi Dropbear murni tidak menggunakan init bawaan OS)

# 3. PERBAIKAN: Memasukkan seluruh port dan argumen langsung ke dalam systemd
cat <<EOF > /etc/systemd/system/dropbear.service
[Unit]
Description=Dropbear Lightweight SSH Server
Documentation=man:dropbear(8)
After=network.target

[Service]
Type=forking
# Masukkan semua custom port yang Anda inginkan di baris ExecStart ini
# Contoh: menjalankan Dropbear di port 143 dan 109
ExecStart=/usr/local/sbin/dropbear -p 143 -p 109
PIDFile=/var/run/dropbear.pid
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Restart dan Enable service di Systemd
systemctl daemon-reload
systemctl stop dropbear >/dev/null 2>&1
systemctl enable dropbear
systemctl start dropbear
echo ""
echo "✅ Instalasi & Konfigurasi Dropbear Selesai!"
