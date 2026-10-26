#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

read -p "Masukkan nama pengguna yang ingin dihapus: " USERNAME

if ! id "$USERNAME" &>/dev/null; then
    echo "Pengguna '$USERNAME' tidak ditemukan."
    exit 1
fi

read -p "Apakah Anda yakin ingin menghapus pengguna '$USERNAME' beserta direktori home-nya? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Penghapusan dibatalkan."
    exit 0
fi

deluser --remove-home "$USERNAME"

echo "✅ Pengguna '$USERNAME' berhasil dihapus."

read -p "$(echo -e "Tekan [Enter] untuk kembali")"
exit 0