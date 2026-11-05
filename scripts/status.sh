#!/bin/bash
set -euo pipefail
CONFIG_PATH="/usr/local/etc/xray/config.json"

echo "=== VPNKu Status ==="
echo "Xray service: $(systemctl is-active xray 2>/dev/null || echo unknown)"
echo "HAProxy service: $(systemctl is-active haproxy 2>/dev/null || echo unknown)"
echo "WARP route: $(jq -r '.routing.rules[] | select(.warpRoute == true) | .outboundTag' "$CONFIG_PATH")"
echo "Unique clients: $(jq '[.inbounds[].settings.clients[]?.email] | unique | length' "$CONFIG_PATH")"
echo "Listening ports:"
ss -tlnp 2>/dev/null | grep -E ':80 |:443 ' || true
echo "==================="