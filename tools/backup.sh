#!/usr/bin/env bash
# Dumps the database and copies the cfg files into a timestamped folder, then
# prunes old ones. Run from cron on the host. Usage:
#   tools/backup.sh <backup-dir> [keep-days]
# Reads DB_HOST, DB_USER, DB_PASS, DB_NAME from the environment, or set
# DB_CONTAINER to dump from a docker container instead.
# server.cfg holds secrets, so the backup dir must not be world readable.
set -euo pipefail
dest=${1:?backup dir}; keep=${2:-14}
root="$(cd "$(dirname "$0")/.." && pwd)"
base="$root/txData/FiveMBasicServerCFXDefault_3A7DA0.base"
stamp=$(date +%Y%m%d-%H%M%S)
out="$dest/$stamp"
umask 077
mkdir -p "$out"

name=${DB_NAME:-stateofmindrp}
if [ -n "${DB_CONTAINER:-}" ]; then
  docker exec "$DB_CONTAINER" sh -c "mariadb-dump -uroot -p\"\$MARIADB_ROOT_PASSWORD\" --single-transaction --routines $name" | gzip > "$out/db.sql.gz"
else
  MYSQL_PWD=${DB_PASS:?DB_PASS} mariadb-dump -h"${DB_HOST:-127.0.0.1}" -u"${DB_USER:?DB_USER}" --single-transaction --routines "$name" | gzip > "$out/db.sql.gz"
fi
gzip -t "$out/db.sql.gz"

for f in server.cfg som.cfg; do [ -f "$base/$f" ] && cp "$base/$f" "$out/$f"; done
sha256sum "$out"/* > "$out/SHA256SUMS"
find "$dest" -mindepth 1 -maxdepth 1 -type d -mtime +"$keep" -exec rm -rf {} +
echo "backup written to $out"
