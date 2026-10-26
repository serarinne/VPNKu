#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then
   echo "Skrip ini harus dijalankan sebagai root" 1>&2
   exit 1
fi

CONFIG_PATH="/usr/local/etc/xray/config.json"

echo "Daftar Klien Saat Ini:"
jq -r '.inbounds[0].settings.clients[] | .email' $CONFIG_PATH | cat -n

if [ $(jq '.inbounds[0].settings.clients | length' $CONFIG_PATH) -eq 0 ]; then
    echo "Tidak ada klien untuk dihapus."
    return
fi

echo ""
read -p "Masukkan email klien yang akan dihapus: " CLIENT_EMAIL

if [ -z "$CLIENT_EMAIL" ]; then
    echo "❌ Email tidak boleh kosong."
    return
fi

if ! jq -e '.inbounds[0].settings.clients[] | select(.email == "'"$CLIENT_EMAIL"'")' $CONFIG_PATH > /dev/null; then
    echo "❌ Klien dengan email '$CLIENT_EMAIL' tidak ditemukan."
    return
fi

TEMP_JSON=$(jq 'del(.inbounds[0].settings.clients[] | select(.email == "'"$CLIENT_EMAIL"'"))' $CONFIG_PATH)

echo "$TEMP_JSON" > $CONFIG_PATH

echo "✅ Klien '$CLIENT_EMAIL' berhasil dihapus."

systemctl restart xray

read -p "$(echo -e "Tekan [Enter] untuk kembali")"
exit 0