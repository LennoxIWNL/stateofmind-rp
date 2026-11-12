#!/usr/bin/env bash
# Proves a backup restores: loads db.sql.gz into a throwaway database and
# compares the table list with setup.sql. Usage:
#   tools/restore-check.sh <backup-folder> [container]
set -euo pipefail
dir=${1:?backup folder}; c=${2:-som-dev-mariadb}
root="$(cd "$(dirname "$0")/.." && pwd)"
pw=$(docker exec "$c" printenv MARIADB_ROOT_PASSWORD)
tmp=restorecheck_$$
sql() { docker exec -i "$c" mariadb -uroot -p"$pw" "$@"; }
trap 'sql -e "DROP DATABASE IF EXISTS $tmp"' EXIT

(cd "$dir" && sha256sum -c SHA256SUMS >/dev/null)
sql -e "CREATE DATABASE $tmp"
gunzip -c "$dir/db.sql.gz" | sql "$tmp"

want=$(grep -oE 'CREATE TABLE IF NOT EXISTS `[a-z0-9_]+`' "$root/setup.sql" | grep -oE '`[a-z0-9_]+`' | tr -d '`' | sort -u)
have=$(sql -N -B "$tmp" -e 'SHOW TABLES' | sort -u)
missing=$(comm -23 <(echo "$want") <(echo "$have"))
[ -z "$missing" ] || { echo "restore is missing tables:"; echo "$missing"; exit 1; }
echo "ok: $(echo "$have" | wc -l) tables restored, all setup.sql tables present"
