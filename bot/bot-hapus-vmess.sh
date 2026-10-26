#!/bin/bash
CONFIG_PATH="/usr/local/etc/xray/config.json"
CLIENT_EMAIL=$1

sed -i "/# Akun-${CLIENT_EMAIL}/d" /usr/local/etc/xray/config.json
echo "1"
systemctl restart xray
