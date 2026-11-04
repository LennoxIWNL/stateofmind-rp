#!/usr/bin/env bash
# Fires N parallel claims at one heist site against a real MariaDB and checks
# that exactly one wins. Usage: tools/load-claims.sh [container] [parallel] [rounds]
# The container needs MARIADB_ROOT_PASSWORD and a stateofmindrp database that
# already has setup.sql imported. Test rows are deleted afterwards.
set -u
c=${1:-som-dev-mariadb}; n=${2:-40}; rounds=${3:-25}
pw=$(docker exec "$c" printenv MARIADB_ROOT_PASSWORD) || exit 2
sql() { docker exec -i "$c" mariadb -uroot -p"$pw" -N -B stateofmindrp -e "$1"; }

fail=0
for r in $(seq 1 "$rounds"); do
  site="loadtest_$r"
  for i in $(seq 1 "$n"); do
    ( sql "INSERT INTO som_heist_runs (site, tier, group_id)
           SELECT '$site', 'store', $i FROM DUAL
           WHERE NOT EXISTS (SELECT 1 FROM som_heist_runs
             WHERE site = '$site' AND (status = 'active' OR created_at > DATE_SUB(NOW(), INTERVAL 45 MINUTE)))" \
        >/dev/null 2>&1 ) &
  done
  wait
  rows=$(sql "SELECT COUNT(*) FROM som_heist_runs WHERE site = '$site'")
  [ "$rows" = "1" ] || { echo "round $r: $rows rows for one site"; fail=1; }
done
sql "DELETE FROM som_heist_runs WHERE site LIKE 'loadtest\_%'"
[ $fail = 0 ] && echo "ok: $rounds rounds x $n parallel claims, one winner each" || echo "FAIL: duplicate claims"
exit $fail
