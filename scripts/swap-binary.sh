#!/usr/bin/env bash
# Ganti binary di dalam container yang sedang berjalan, tanpa docker build dan
# tanpa menghapus container. Jika versi baru tidak sehat, binary lama dikembalikan.
#
# Pemakaian: swap-binary.sh <container> <binary-baru> <versi> [url]
set -euo pipefail

CONTAINER="${1:?nama container}"
NEW_BIN="${2:?path binary baru}"
VERSION="${3:?versi yang diharapkan}"
URL="${4:-http://localhost:8080/}"
TARGET="/app/myapp"
BACKUP="${NEW_BIN}.prev"

# Tunggu sampai GET / mengembalikan baris yang diharapkan (maks ~15 detik).
wait_for() {
  for _ in $(seq 1 50); do
    if curl -fsS --max-time 1 "$URL" 2>/dev/null | grep -qxF "$1"; then
      return 0
    fi
    sleep 0.2
  done
  return 1
}

swap() {
  echo "[2/4] Copy binary baru ke $CONTAINER:$TARGET"
  docker cp "$NEW_BIN" "$CONTAINER:$TARGET" || return 1
  echo "[3/4] Restart container"
  docker restart "$CONTAINER" >/dev/null || return 1
  echo "[4/4] Health check: menunggu version=$VERSION"
  wait_for "Hello, DevOps! version=$VERSION"
}

BEFORE="$(curl -fsS --max-time 2 "$URL" || true)"
echo "Sebelum : ${BEFORE:-tidak merespons}"

echo "[1/4] Backup binary lama ke $BACKUP"
docker cp "$CONTAINER:$TARGET" "$BACKUP"

start=$(date +%s%N)

if swap; then
  echo "Sesudah : $(curl -fsS "$URL")"
  echo "Swap sampai sehat: $(( ($(date +%s%N) - start) / 1000000 )) ms"
  exit 0
fi

echo "GAGAL: version=$VERSION tidak sehat, rollback ke binary lama" >&2
docker cp "$BACKUP" "$CONTAINER:$TARGET"
docker restart "$CONTAINER" >/dev/null

if [ -n "$BEFORE" ] && wait_for "$BEFORE"; then
  echo "Rollback OK: $BEFORE" >&2
else
  echo "Rollback selesai, tapi versi lama belum merespons. Cek: docker logs $CONTAINER" >&2
fi

exit 1