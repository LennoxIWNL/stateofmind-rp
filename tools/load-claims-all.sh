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
# name | setup SQL | claim SQL (run N times in parallel, each must report affected rows)
run() {
  local name=$1 setup=$2 claim=$3
  for r in $(seq 1 "$rounds"); do
    sql "$setup" >/dev/null
    # @N@ in a claim is 0 or 1 by connection, so one claim can be aimed at two rows.
    for i in $(seq 1 "$n"); do ( stmt=${claim//@N@/$((i % 2))}; sql "$stmt; SELECT ROW_COUNT();" 2>/dev/null | tail -1 >> /tmp/claimcount.$$ ) & done
    wait
    wins=$(awk '{s += $1} END {print s+0}' /tmp/claimcount.$$); rm -f /tmp/claimcount.$$
    [ "$wins" = "1" ] || { echo "$name round $r: $wins winners"; fail=1; }
  done
  echo "checked $name"
}

cleanup() {
  sql "DELETE FROM som_plants WHERE citizenid = 'LOADTEST'; DELETE FROM som_trade_offers WHERE seller = 'LOADTEST'; DELETE FROM som_lab_jobs WHERE citizenid LIKE 'LOADTEST%'; DELETE FROM som_chop_log WHERE citizenid LIKE 'LOADTEST%'; DELETE FROM som_turf WHERE name = 'loadtest_zone'; DELETE FROM som_trade_offers WHERE buyer = 'LOADTEST'; DELETE FROM som_shops WHERE shop_id LIKE 'loadshop%'; DELETE FROM som_property_leases WHERE property_id IN (99998, 99999);" >/dev/null
}
trap cleanup EXIT

run "plant harvest" \
  "DELETE FROM som_plants WHERE citizenid='LOADTEST'; INSERT INTO som_plants (citizenid, strain, x, y, z) VALUES ('LOADTEST','s',0,0,0)" \
  "UPDATE som_plants SET status = 'harvested' WHERE citizenid = 'LOADTEST' AND status = 'growing'"

run "trade accept" \
  "DELETE FROM som_trade_offers WHERE seller='LOADTEST'; INSERT INTO som_trade_offers (seller, buyer, item, price) VALUES ('LOADTEST','B','repairkit',200)" \
  "UPDATE som_trade_offers SET status = 'done' WHERE seller = 'LOADTEST' AND buyer = 'B' AND status = 'pending' AND created_at > DATE_SUB(NOW(), INTERVAL 120 SECOND)"

run "turf claim of an unowned zone" \
  "DELETE FROM som_turf WHERE name='loadtest_zone'; INSERT INTO som_turf (name, label) VALUES ('loadtest_zone','L')" \
  "UPDATE som_turf SET owner_gang = 'ballas', claimed_at = NOW() WHERE name = 'loadtest_zone' AND owner_gang IS NULL"

run "lab start (one cook per lab)" \
  "DELETE FROM som_lab_jobs WHERE citizenid LIKE 'LOADTEST%'" \
  "INSERT INTO som_lab_jobs (citizenid, lab, recipe, ready_at) SELECT 'LOADTEST', 'loadlab', 'r', DATE_ADD(NOW(), INTERVAL 10 MINUTE) FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM som_lab_jobs WHERE lab = 'loadlab' AND status = 'cooking')"

run "chop shop (drop-off and plate cooldown)" \
  "DELETE FROM som_chop_log WHERE citizenid LIKE 'LOADTEST%'" \
  "INSERT INTO som_chop_log (citizenid, dropoff, plate) SELECT 'LOADTEST', 'loaddrop', 'LOAD1' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM som_chop_log WHERE dropoff = 'loaddrop' AND created_at > DATE_SUB(NOW(), INTERVAL 10 MINUTE)) AND NOT EXISTS (SELECT 1 FROM som_chop_log WHERE plate = 'LOAD1' AND created_at > DATE_SUB(NOW(), INTERVAL 1440 MINUTE))"

run "shop purchase (one shop per person, either of two shops)" \
  "DELETE FROM som_shops WHERE shop_id LIKE 'loadshop%'; INSERT INTO som_shops (shop_id, business) VALUES ('loadshop0','x'), ('loadshop1','x')" \
  "UPDATE som_shops SET owner = 'LOADTEST', bought_price = 1, bought_at = NOW(), withdraw_at = NULL WHERE shop_id = 'loadshop@N@' AND owner IS NULL AND (SELECT COUNT(*) FROM (SELECT 1 FROM som_shops WHERE owner = 'LOADTEST') x) = 0"

run "lease start (one lease per property, two would-be tenants)" \
  "DELETE FROM som_property_leases WHERE property_id = 99999" \
  "INSERT INTO som_property_leases (property_id, landlord, tenant, rent, next_due) SELECT 99999, 'LOADTEST', 'LOADT@N@', 500, DATE_ADD(NOW(), INTERVAL 7 DAY) FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM som_property_leases WHERE property_id = 99999 AND status = 'active') AND (SELECT COUNT(*) FROM som_property_leases WHERE tenant = 'LOADT@N@' AND status = 'active') < 2"

run "lease rent week (one charge per due week)" \
  "DELETE FROM som_property_leases WHERE property_id = 99998; INSERT INTO som_property_leases (id, property_id, landlord, tenant, rent, next_due) VALUES (900001, 99998, 'LOADTEST', 'LOADT0', 500, '2026-01-01 00:00:00')" \
  "UPDATE som_property_leases SET next_due = DATE_ADD(next_due, INTERVAL 7 DAY), missed_cycles = missed_cycles + 0 WHERE id = 900001 AND status = 'active' AND UNIX_TIMESTAMP(next_due) = UNIX_TIMESTAMP('2026-01-01 00:00:00')"

# Same statement as the insert in som-mechanic/server/trade.lua fallbackBuy; change both together.
run "roadside kit (one per hour)" \
  "DELETE FROM som_trade_offers WHERE buyer='LOADTEST'" \
  "INSERT INTO som_trade_offers (seller, buyer, item, price, status) SELECT 'FALLBACK', 'LOADTEST', 'repairkit', 200, 'done' FROM DUAL WHERE (SELECT COUNT(*) FROM som_trade_offers WHERE buyer = 'LOADTEST' AND seller = 'FALLBACK' AND status <> 'cancelled' AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)) < 1"

[ $fail = 0 ] && echo "ok: every claim has exactly one winner under $n parallel connections" || echo "FAIL: a claim let more than one through"
exit $fail
