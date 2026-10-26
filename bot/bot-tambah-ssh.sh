#!/bin/bash
USERNAME="ssh-${1}"
PASSWORD=$2

if id "${USERNAME}" &>/dev/null; then
    echo "Pengguna '${USERNAME}' sudah ada. Silakan pilih nama lain."
    exit 1
fi

adduser --quiet --disabled-password --gecos "" "${USERNAME}"

echo "${USERNAME}:${PASSWORD}" | chpasswd

echo "1"
