#!/bin/bash
CONFIG_PATH="/usr/local/etc/xray/config.json"
CLIENT_EMAIL=$1
NEW_UUID=$2

if [ -z "${CLIENT_EMAIL}" ]; then
    echo "Email tidak boleh kosong."
    return
fi

CLIENT_EXISTS=$(grep -w ${CLIENT_EMAIL} /usr/local/etc/xray/config.json | wc -l)

if [[ ${CLIENT_EXISTS} == '1' ]]; then
   echo "Klien dengan email '${CLIENT_EMAIL}' sudah ada."
   return
fi

sed -i '/#USER_ACCOUNT/a ,{"id": "'${NEW_UUID}'", "alterId": 0, "level": 0, "security": "auto", "email": "'${CLIENT_EMAIL}'"} # Akun-'${CLIENT_EMAIL}'' /usr/local/etc/xray/config.json

echo "1"

systemctl restart xray
