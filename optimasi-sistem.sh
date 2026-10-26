#!/bin/bash

# Pastikan skrip dijalankan sebagai root
if [ "$(id -u)" -ne 0 ]; then
    echo "Skrip ini harus dijalankan sebagai root" 1>&2
    exit 1
fi

SYSCTL_CONFIG="/etc/sysctl.conf"

echo "=> Memulai Optimasi BBR & TCP..."

# Fungsi untuk menambahkan/memperbarui pengaturan sysctl dengan aman
set_sysctl_config() {
    local key="$1"
    local value="$2"
    
    # Hapus baris lama jika ada, lalu tambahkan yang baru
    sed -i "/^${key}/d" "$SYSCTL_CONFIG"
    echo "${key}=${value}" >> "$SYSCTL_CONFIG"
}

# 1. Muat modul BBR untuk memastikannya aktif
modprobe tcp_bbr

# 2. Terapkan konfigurasi kernel (tidak akan ada duplikasi)
set_sysctl_config "net.core.default_qdisc" "fq"
set_sysctl_config "net.ipv4.tcp_congestion_control" "bbr"
set_sysctl_config "fs.file-max" "51200"
set_sysctl_config "net.core.rmem_max" "67108864"
set_sysctl_config "net.core.wmem_max" "67108864"
set_sysctl_config "net.core.netdev_max_backlog" "250000"
set_sysctl_config "net.core.somaxconn" "4096"
set_sysctl_config "net.ipv4.tcp_syncookies" "1"
set_sysctl_config "net.ipv4.tcp_tw_reuse" "1"
set_sysctl_config "net.ipv4.tcp_fin_timeout" "30"
set_sysctl_config "net.ipv4.tcp_keepalive_time" "1200"
set_sysctl_config "net.ipv4.ip_local_port_range" "10000 65000"
set_sysctl_config "net.ipv4.tcp_max_syn_backlog" "8192"

# 3. Terapkan perubahan segera
sysctl -p >/dev/null 2>&1

echo "✅ Optimasi BBR & TCP Selesai!"
echo ""
echo "=> Memulai Konfigurasi Firewall..."

# 1. Instal iptables-persistent untuk menyimpan aturan firewall
apt-get install -y iptables-persistent

# 2. Hapus aturan lama (jika ada) dan tambahkan aturan baru yang benar
# PERBAIKAN: Menggunakan rantai OUTPUT untuk trafik dari server
iptables -F OUTPUT
iptables -A OUTPUT -m string --string "get_peers" --algo bm -j DROP
iptables -A OUTPUT -m string --string "announce_peer" --algo bm -j DROP
iptables -A OUTPUT -m string --string "find_node" --algo bm -j DROP
iptables -A OUTPUT -m string --algo bm --string "BitTorrent" -j DROP
iptables -A OUTPUT -m string --algo bm --string "torrent" -j DROP
iptables -A OUTPUT -m string --algo bm --string "info_hash" -j DROP

# 3. Simpan aturan agar permanen
iptables-save > /etc/iptables/rules.v4

echo "✅ Konfigurasi Firewall Selesai!"
echo "CATATAN: ddos-deflate tidak diinstal karena sudah usang. Gunakan Fail2Ban."
