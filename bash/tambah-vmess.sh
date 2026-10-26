#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

read -p "Masukkan email untuk klien baru: " CLIENT_EMAIL

if [ -z "$CLIENT_EMAIL" ]; then
    echo "Email tidak boleh kosong."
    return
fi

CLIENT_EXISTS=$(grep -w $CLIENT_EMAIL /usr/local/etc/xray/config.json | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
   echo "Klien dengan email '$CLIENT_EMAIL' sudah ada."
   return
fi

NEW_UUID=$(xray uuid)

sed -i '/#USER_ACCOUNT/a ,{"id": "'${NEW_UUID}'", "alterId": 0, "level": 0, "security": "auto", "email": "'${CLIENT_EMAIL}'"} # Akun-'${CLIENT_EMAIL}'' /usr/local/etc/xray/config.json

echo "✅ Klien berhasil ditambahkan!"
echo "   Email: $CLIENT_EMAIL"
echo "   UUID : $NEW_UUID"

systemctl restart xray

read -p "$(echo -e "Tekan [Enter] untuk kembali")"
exit 0
