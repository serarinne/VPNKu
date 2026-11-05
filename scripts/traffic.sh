#!/bin/bash
set -euo pipefail
API="127.0.0.1:6969"

RESET=0
if [ "${1:-}" = "--reset" ] || [ "${1:-}" = "reset" ]; then
    RESET=1
fi

if [ "$RESET" -eq 1 ]; then
    xray api stats -s "$API" -reset >/dev/null 2>&1 || true
    echo "[OK] Usage statistics reset."
    exit 0
fi

echo "=== Bandwidth Usage per User ==="
echo " (uplink = upload from server, downlink = download to server) "
echo ""

RAW=$(xray api statsquery -s "$API" -pattern "user>>>" 2>/dev/null || true)

if [ -z "$RAW" ]; then
    echo "[INFO] No data. Ensure Xray is running and StatsService is enabled."
    exit 0
fi

echo "$RAW" | awk '
  /name:/ {
    gsub(/.*name:[ \t]*"?/, ""); gsub(/"?[ \t]*$/, "");
    name = $0;
  }
  /value:/ {
    gsub(/.*value:[ \t]*/, "");
    val = $0 + 0;
    if (name ~ />>>traffic>>>uplink$/) {
      sub(/>>>traffic>>>uplink$/, "", name);
      sub(/^user>>>/, "", name);
      up[name] = val;
    } else if (name ~ />>>traffic>>>downlink$/) {
      sub(/>>>traffic>>>downlink$/, "", name);
      sub(/^user>>>/, "", name);
      down[name] = val;
    }
    name = "";
  }
  END {
    printf "%-32s %12s %12s\n", "EMAIL", "UPLOAD(MB)", "DOWNLOAD(MB)";
    printf "%-32s %12s %12s\n", "-----", "----------", "-----------";
    for (u in up) {
      printf "%-32s %12.2f %12.2f\n", u, up[u]/1048576, (down[u]+0)/1048576;
    }
  }
'

echo ""
echo "Note: stats reset on Xray restart. Use 'traffic --reset' for periodic snapshots."