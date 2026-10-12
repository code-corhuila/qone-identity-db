#!/usr/bin/env sh
# The rebuild check of Annex A and 06-data/migration-strategy.md, against a fresh instance:
#   1. migrate from an empty database        -> the schema builds from zero
#   2. migrate again                         -> "No migration necessary" (incremental)
#   3. every U script in reverse, with psql  -> the schema and the roles are gone
#   4. migrate again                         -> after undo, it builds again
#   5. validate                              -> checksums match the files
#   6. apply the seed twice, count the rows  -> seeds are idempotent
# Usage: scripts/rebuild-check.sh   (needs Docker and python3; uses deploy/compose.yml with a throwaway project)
set -eu
cd "$(dirname "$0")/.."
export IDENTITY_DB_NAME="${IDENTITY_DB_NAME:-identity}"
export IDENTITY_DB_USER="${IDENTITY_DB_USER:-identity}"
export IDENTITY_DB_PASSWORD="${IDENTITY_DB_PASSWORD:-rebuild-check}"
PY=python3; for c in python3 python; do if "$c" -c "import sys" >/dev/null 2>&1; then PY=$c; break; fi; done
export FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH="${FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH:-$($PY scripts/hash-password.py rebuild-check)}"
PROJECT="identity-db-check"
DC="docker compose -p $PROJECT -f deploy/compose.yml"
docker network inspect platform >/dev/null 2>&1 || docker network create platform >/dev/null
cleanup() { $DC --profile migrate down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

fail() { echo "FAIL: $1" >&2; exit 1; }
migrate() { $DC --profile migrate run --rm identity-db-migrate "$@"; }
psql_db() { $DC exec -T identity-db psql -v ON_ERROR_STOP=1 -U "$IDENTITY_DB_USER" -d "$IDENTITY_DB_NAME" "$@"; }

echo "== 1. migrate from an empty database"
$DC up -d identity-db --wait
migrate migrate | tee /tmp/migrate-1.log
grep -q "Successfully applied" /tmp/migrate-1.log || fail "the first migrate applied nothing"

echo "== 2. migrate again applies nothing"
migrate migrate | tee /tmp/migrate-2.log
grep -q "No migration necessary" /tmp/migrate-2.log || fail "the second migrate applied something"

echo "== 3. every U script, from the highest version to the lowest"
for v in $(find migrations -path migrations/undo -prune -o -name 'V*__*.sql' -print | sed -E 's#.*/V([0-9]+)__.*#\1#' | sort -r); do
  u=$(find migrations/undo -name "U${v}__*.sql" | head -n1)
  [ -n "$u" ] || fail "V${v} has no U${v} script in migrations/undo"
  if [ "$v" = "002" ]; then
    domain_tables=$(psql_db -tA -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'identity' AND table_name <> 'flyway_schema_history'")
    [ "$domain_tables" = "0" ] || fail "$domain_tables table(s) of the domain survived the undo scripts"
  fi
  echo "-- $u"
  psql_db < "$u" >/dev/null
done
left=$(psql_db -tA -c "SELECT count(*) FROM information_schema.schemata WHERE schema_name = 'identity'")
[ "$left" = "0" ] || fail "schema identity still exists after the undo scripts"
roles=$(psql_db -tA -c "SELECT count(*) FROM pg_roles WHERE rolname IN ('identity_reader','identity_writer')")
[ "$roles" = "0" ] || fail "the identity roles still exist after the undo scripts"

echo "== 4. migrate again (the history went with the schema)"
migrate migrate | tee /tmp/migrate-3.log
grep -q "Successfully applied" /tmp/migrate-3.log || fail "the rebuild after the undo applied nothing"

echo "== 5. validate"
migrate validate

echo "== 6. the seed is idempotent and holds no password"
grep -q 'password_hash' migrations/02_dml/V007__seed_app_user.sql || fail "seed shape changed"
grep -qE "'[0-9a-f]{32}\\\$[0-9a-f]{64}'" migrations/02_dml/V007__seed_app_user.sql && fail "a password hash is written in the seed file"
sed "s/\${demo_password_hash}/$FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH/g" migrations/02_dml/V007__seed_app_user.sql | psql_db >/dev/null
sed "s/\${demo_password_hash}/$FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH/g" migrations/02_dml/V007__seed_app_user.sql | psql_db >/dev/null
rows=$(psql_db -tA -c "SELECT count(*) FROM identity.app_user")
[ "$rows" = "9" ] || fail "expected 9 seeded users, found $rows"
public_tables=$(psql_db -tA -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'")
[ "$public_tables" = "0" ] || fail "a table lives in public"

echo "OK: qone-identity-db rebuilds from zero, applies nothing twice, undoes completely, rebuilds, validates and seeds idempotently"
