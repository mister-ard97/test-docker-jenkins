#!/usr/bin/env bash
# Polling GET / setiap ~0,5 detik dan catat jam + respons (atau DOWN kalau gagal).
# Dipakai untuk mengukur downtime selama swap binary. Hentikan dengan Ctrl+C.
#
# Pemakaian: watch-downtime.sh [url] | tee docs/downtime.log
URL="${1:-http://localhost:8080/}"

while true; do
  ts="$(date +%H:%M:%S.%3N)"
  echo "$ts $(curl -fsS --max-time 1 "$URL" 2>/dev/null || echo DOWN)"
  sleep 0.5
done
