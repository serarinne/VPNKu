#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

read -p "Masukkan nama pengguna baru: " USERNAME
read -sp "Masukkan kata sandi untuk pengguna baru: " PASSWORD

if id "$USERNAME" &>/dev/null; then
    echo "Pengguna '$USERNAME' sudah ada. Silakan pilih nama lain."
    exit 1
fi

adduser --quiet --disabled-password --gecos "" "$USERNAME"

echo "$USERNAME:$PASSWORD" | chpasswd

echo "✅ Akun SSH berhasil dibuat!"
echo "   Nama Pengguna: $USERNAME"
echo "   Kata Sandi   : $PASSWORD"

read -p "$(echo -e "Tekan [Enter] untuk kembali")"
exit 0