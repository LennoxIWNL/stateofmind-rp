---
name: oxmysql
description: oxmysql usage in this repo (await variants, return values, atomic claims, schema conventions). Load before writing SQL.
---

# oxmysql

- Always the `.await` forms inside callbacks: `MySQL.query.await` (rows), `MySQL.single.await` (one row or nil), `MySQL.scalar.await` (first column), `MySQL.insert.await` (insertId, 0 or nil when no row was inserted), `MySQL.update.await` (affected rows), `MySQL.transaction.await({ { query, values } })`.
- Parameters are `?` placeholders with a values table. Never concatenate input into SQL.
- A check-then-pay-then-write sequence is a race. Claim first with one atomic statement and check the result:
  - `UPDATE t SET state = 'x' WHERE id = ? AND state = 'y'` then `affected >= 1`.
  - Single winner insert: `INSERT INTO t (...) SELECT ?, ? FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM t WHERE ... AND created_at > DATE_SUB(NOW(), INTERVAL ? MINUTE))` then `insertId > 0`. Verified under 40 parallel claimers with `tools/load-claims.sh`.
- Time based state is computed from database timestamps (`NOW()`, `TIMESTAMPDIFF`, `DATE_ADD`), never an in-memory countdown, so restarts change nothing.
- Schema lives only in `setup.sql` (numbered sections, `CREATE TABLE IF NOT EXISTS`, `som_` prefix, `ENUM` for closed vocabularies, `BIGINT` money, no foreign keys into third party tables). Run every new statement on the dev database: `docker exec -i som-dev-mariadb mariadb -uroot -pdevonly stateofmindrp`.
- Add the exact query strings to `tests/mocks/mysql.lua`; an unrecognised query fails loudly on purpose (see the `som-testing` skill).
