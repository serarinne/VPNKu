#!/bin/bash
USERNAME="ssh-${1}"

if ! id "${USERNAME}" &>/dev/null; then
    echo "Pengguna '${USERNAME}' tidak ditemukan."
    exit 1
fi

deluser --remove-home "${USERNAME}" &>/dev/null

echo "1"
