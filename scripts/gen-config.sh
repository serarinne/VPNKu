#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"
DOMAIN=$(cat /etc/vps-data/domain 2>/dev/null || echo "example.com")
PORT=443

# Custom address / SNI / host (wildcard & custom)
# Defaults: address = support.zoom.us ; sni/host = support.zoom.us.<domain>
GEN_ADDR="${GEN_ADDR:-support.zoom.us}"
GEN_SNI="${GEN_SNI:-support.zoom.us.${DOMAIN}}"
GEN_HOST="${GEN_HOST:-support.zoom.us.${DOMAIN}}"

# Allow override via config file
if [ -f /etc/vps-data/gen-config.conf ]; then
    # shellcheck source=/dev/null
    . /etc/vps-data/gen-config.conf
fi

ADDR="${GEN_ADDR}"
SNI="${GEN_SNI}"
HOST="${GEN_HOST}"

if [ "$(id -u)" -ne 0 ]; then
   echo "[ERR] This script must be run as root" 1>&2
   exit 1
fi

EMAIL="${1:-}"
if [ -z "$EMAIL" ]; then
    echo "Available clients:"
    jq -r '[.inbounds[].settings.clients[]?.email] | unique | .[]' "$CONFIG_PATH" | cat -n
    echo ""
    read -rp "Enter client email: " EMAIL
fi

# Find UUID for this email (from any inbound)
UUID=$(jq -r --arg e "$EMAIL" '[.inbounds[].settings.clients[]? | select(.email == $e) | .id] | .[0]' "$CONFIG_PATH")
if [ -z "$UUID" ] || [ "$UUID" = "null" ]; then
    echo "[ERR] Client '$EMAIL' not found."
    exit 1
fi

OUTDIR="/root/vpn-configs"
mkdir -p "$OUTDIR"
OUTFILE="${OUTDIR}/${EMAIL}.txt"
: > "$OUTFILE"

gen_vmess() {
    local name="$1"; local net="$2"; local path="$3"; local extra="$4"
    local json
    json=$(jq -n \
        --arg v "2" --arg ps "$name" --arg add "$ADDR" --arg port "$PORT" \
        --arg id "$UUID" --arg aid "0" --arg scy "auto" --arg net "$net" \
        --arg type "none" --arg host "$HOST" --arg path "$path" \
        --arg tls "tls" --arg sni "$SNI" \
        '{v:$v,ps:$ps,add:$add,port:$port,id:$id,aid:$aid,scy:$scy,net:$net,type:$type,host:$host,path:$path,tls:$tls,sni:$sni}')
    local b64
    b64=$(echo -n "$json" | base64 -w 0)
    echo "vmess://${b64}"
}

gen_vless() {
    local name="$1"; local params="$2"
    echo "vless://${UUID}@${ADDR}:${PORT}?${params}#${name}"
}

{
echo "=== VPN Config for: $EMAIL ==="
echo "Domain: $DOMAIN  Port: $PORT  UUID: $UUID"
echo ""

echo "--- VMess WebSocket ---"
gen_vmess "VMess-WS-${EMAIL}" "ws" "/vmess" ""
echo ""
echo "--- VLESS WebSocket ---"
gen_vless "VLESS-WS-${EMAIL}" "encryption=none&security=tls&sni=${SNI}&fp=chrome&type=ws&host=${HOST}&path=%2Fvless"
echo ""
echo "--- VMess gRPC ---"
gen_vmess "VMess-gRPC-${EMAIL}" "grpc" "vmess-grpc" ""
# vmess grpc needs serviceName in path? v2rayN uses path for serviceName in grpc
echo ""
echo "--- VLESS gRPC ---"
gen_vless "VLESS-gRPC-${EMAIL}" "encryption=none&security=tls&sni=${SNI}&fp=chrome&type=grpc&serviceName=vless-grpc&mode=gun"
echo ""
echo "--- VMess HTTPUpgrade ---"
gen_vmess "VMess-HU-${EMAIL}" "httpupgrade" "/vmess-hu" ""
echo ""
echo "--- VLESS HTTPUpgrade ---"
gen_vless "VLESS-HU-${EMAIL}" "encryption=none&security=tls&sni=${SNI}&fp=chrome&type=httpupgrade&host=${HOST}&path=%2Fvless-hu"
echo ""
} | tee "$OUTFILE"

echo ""
echo "[OK] Config saved to $OUTFILE"
