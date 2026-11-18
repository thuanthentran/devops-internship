#!/usr/bin/env bash
set -euo pipefail

mkdir -p /home/ubuntu/reports

cd /home/ubuntu/music
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
out=/home/ubuntu/reports/nginx-$(date +%F).txt
docker compose logs --no-log-prefix --since 24h nginx > "$tmp"
echo "== Top IP ==" > "$out"
awk '$9 ~ /^[0-9][0-9][0-9]$/{c[$1]++} END {for (k in c) print c[k], k}' "$tmp" | sort -rn | head -10 >> "$out"
echo "== Top Endpoint ==" >> "$out"
awk '$9 ~ /^[0-9][0-9][0-9]$/{split($7, a, "?"); c[a[1]]++} END {for (k in c) print c[k], k}' "$tmp" | sort -rn | head -10 >> "$out"
echo "== Top Status Code ==" >> "$out"
awk '$9 ~ /^[0-9][0-9][0-9]$/{c[$9]++} END {for (k in c) print c[k], k}' "$tmp" | sort -rn | head -10 >> "$out"
echo "Done. Reports generated at /home/ubuntu/reports"