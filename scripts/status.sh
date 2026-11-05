#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"

echo "=== VPNKu Status ==="
echo "Xray service: $(systemctl is-active xray 2>/dev/null || echo unknown)"
echo "HAProxy service: $(systemctl is-active haproxy 2>/dev/null || echo unknown)"
echo "WARP route: $(jq -r '.routing.rules[] | select(.warpRoute == true) | .outboundTag' "$CONFIG_PATH")"
echo "Unique clients: $(jq '[.inbounds[].settings.clients[]?.email] | unique | length' "$CONFIG_PATH")"
PORTS=$(ss -tlnp 2>/dev/null | grep -oE ':(80|443) ' | tr -d ' :' | sort -nu | paste -sd ', ' -)
echo "Listening ports: ${PORTS:-none}"
DOMAIN=$(cat /etc/vps-data/domain 2>/dev/null || true)
echo "--- Info ---"
echo "Domain: ${DOMAIN:-N/A}"
echo "Port: 443"
echo "WS: /vmess , /vless"
echo "HU: /vmess-hu , /vless-hu"
echo "gRPC: vmess-grpc , vless-grpc"
echo "==================="
