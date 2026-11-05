#!/usr/bin/env bash
# Fires N parallel connections at every "claim" query in the game against a real
# MariaDB and checks exactly one wins each time: plant harvest, trade accept, lab
# start, chop shop, turf claim and takeover. Complements tools/load-claims.sh
# (heist sites). Usage: tools/load-claims-all.sh [container] [parallel] [rounds]
# Test rows are removed afterwards. Made by Lennox.
set -u
c=${1:-som-dev-mariadb}; n=${2:-30}; rounds=${3:-5}
# DIRECT=1 talks to a database on 127.0.0.1 (as in CI) instead of a docker container.
if [ "${DIRECT:-0}" = 1 ]; then
  sql() { mariadb -h127.0.0.1 -uroot -p"${DB_PASS:-root}" -N -B stateofmindrp -e "$1"; }
else
  pw=$(docker exec "$c" printenv MARIADB_ROOT_PASSWORD) || exit 2
  sql() { docker exec -i "$c" mariadb -uroot -p"$pw" -N -B stateofmindrp -e "$1"; }
fi

fail=0
# name | setup SQL | claim SQL (run N times in parallel, each must report affected rows) | check SQL (must print 1)
run() {
  local name=$1 setup=$2 claim=$3 check=$4
  for r in $(seq 1 "$rounds"); do
    sql "$setup" >/dev/null
    for i in $(seq 1 "$n"); do ( sql "$claim; SELECT ROW_COUNT();" 2>/dev/null | tail -1 >> /tmp/claimcount.$$ ) & done
    wait
    wins=$(awk '{s += $1} END {print s+0}' /tmp/claimcount.$$); rm -f /tmp/claimcount.$$
    [ "$wins" = "1" ] || { echo "$name round $r: $wins winners"; fail=1; }
  done
  echo "checked $name"
}

cleanup() {
  sql "DELETE FROM som_plants WHERE citizenid = 'LOADTEST'; DELETE FROM som_trade_offers WHERE seller = 'LOADTEST'; DELETE FROM som_lab_jobs WHERE citizenid LIKE 'LOADTEST%'; DELETE FROM som_chop_log WHERE citizenid LIKE 'LOADTEST%'; DELETE FROM som_turf WHERE name = 'loadtest_zone';" >/dev/null
}
trap cleanup EXIT

run "plant harvest" \
  "DELETE FROM som_plants WHERE citizenid='LOADTEST'; INSERT INTO som_plants (citizenid, strain, x, y, z) VALUES ('LOADTEST','s',0,0,0)" \
  "UPDATE som_plants SET status = 'harvested' WHERE citizenid = 'LOADTEST' AND status = 'growing'" ""

run "trade accept" \
  "DELETE FROM som_trade_offers WHERE seller='LOADTEST'; INSERT INTO som_trade_offers (seller, buyer, item, price) VALUES ('LOADTEST','B','repairkit',200)" \
  "UPDATE som_trade_offers SET status = 'done' WHERE seller = 'LOADTEST' AND buyer = 'B' AND status = 'pending' AND created_at > DATE_SUB(NOW(), INTERVAL 120 SECOND)" ""

run "turf claim of an unowned zone" \
  "DELETE FROM som_turf WHERE name='loadtest_zone'; INSERT INTO som_turf (name, label) VALUES ('loadtest_zone','L')" \
  "UPDATE som_turf SET owner_gang = 'ballas', claimed_at = NOW() WHERE name = 'loadtest_zone' AND owner_gang IS NULL" ""

run "lab start (one cook per lab)" \
  "DELETE FROM som_lab_jobs WHERE citizenid LIKE 'LOADTEST%'" \
  "INSERT INTO som_lab_jobs (citizenid, lab, recipe, ready_at) SELECT 'LOADTEST', 'loadlab', 'r', DATE_ADD(NOW(), INTERVAL 10 MINUTE) FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM som_lab_jobs WHERE lab = 'loadlab' AND status = 'cooking')" ""

run "chop shop (drop-off and plate cooldown)" \
  "DELETE FROM som_chop_log WHERE citizenid LIKE 'LOADTEST%'" \
  "INSERT INTO som_chop_log (citizenid, dropoff, plate) SELECT 'LOADTEST', 'loaddrop', 'LOAD1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM som_chop_log WHERE dropoff = 'loaddrop' AND created_at > DATE_SUB(NOW(), INTERVAL 10 MINUTE)) AND NOT EXISTS (SELECT 1 FROM som_chop_log WHERE plate = 'LOAD1' AND created_at > DATE_SUB(NOW(), INTERVAL 1440 MINUTE))" ""

[ $fail = 0 ] && echo "ok: every claim has exactly one winner under $n parallel connections" || echo "FAIL: a claim let more than one through"
exit $fail
