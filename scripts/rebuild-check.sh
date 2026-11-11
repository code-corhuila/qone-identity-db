#!/usr/bin/env sh
# The rebuild check of Annex A and 06-data/migration-strategy.md, against a fresh instance:
#   1. migrate from an empty database        -> the schema builds from zero
#   2. migrate again                         -> "No migration necessary" (incremental)
#   3. every U script in reverse, with psql  -> the schema and the roles are gone
#   4. migrate again                         -> after undo, it builds again
#   5. validate                              -> checksums match the files
#   6. apply the seed twice, count the rows  -> seeds are idempotent, synthetic, no ADMIN
#   7. flyway.toml never lists 04_demo, one location per line (how qone-infra reads it)
#   8. migrate a fresh database without the demo location  -> no demo people (qa, main)
# Steps 1-6 run as develop does: qone-infra's migrate.sh passes -locations=<flyway.toml list>,
# filesystem:migrations/04_demo (IDENTITY_DEMO_LOCATION). Step 0 is the static seed guard.
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
cleanup() { $DC --profile tooling down -v --remove-orphans >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup

fail() { echo "FAIL: $1" >&2; exit 1; }
IDENTITY_DEMO_LOCATION="filesystem:migrations/04_demo"
# The same parse as qone-infra/scripts/migrate.sh: the locations of flyway.toml, one per line.
BASE_LOCATIONS=$(sed -n 's/^[[:space:]]*"\(filesystem:[^"]*\)",\{0,1\}[[:space:]]*$/\1/p' flyway.toml | paste -sd, -)
DEVELOP="-locations=$BASE_LOCATIONS,$IDENTITY_DEMO_LOCATION"
migrate() { $DC --profile tooling run --rm identity-db-migrate "$DEVELOP" "$@"; }
migrate_plain() { $DC --profile tooling run --rm identity-db-migrate "$@"; }
psql_db() { $DC exec -T identity-db psql -v ON_ERROR_STOP=1 -U "$IDENTITY_DB_USER" -d "$IDENTITY_DB_NAME" "$@"; }

echo "== 0. seed e-mails on .test, no password hash in any migration"
sh scripts/check-seed-identities.sh

echo "== 1. migrate from an empty database (develop: with the demo people)"
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

echo "== 6. the demo seed is idempotent, synthetic and holds no password"
SEED=migrations/04_demo/V007__seed_app_user.sql
grep -q 'password_hash' "$SEED" || fail "seed shape changed"
sed "s/\${demo_password_hash}/$FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH/g" "$SEED" | psql_db >/dev/null
sed "s/\${demo_password_hash}/$FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH/g" "$SEED" | psql_db >/dev/null
rows=$(psql_db -tA -c "SELECT count(*) FROM identity.app_user")
[ "$rows" = "8" ] || fail "expected 8 seeded users, found $rows"
admins=$(psql_db -tA -c "SELECT count(*) FROM identity.app_user WHERE role = 'ADMIN'")
[ "$admins" = "0" ] || fail "the seed creates an ADMIN; the ADMIN belongs to the bootstrap of qone-identity-api"
real=$(psql_db -tA -c "SELECT count(*) FROM identity.app_user WHERE email !~ '[.]test\$' OR name !~ '^(Estudiante|Profesor) Demo [0-9]{2}\$'")
[ "$real" = "0" ] || fail "$real seeded user(s) are not synthetic (name Estudiante/Profesor Demo NN, e-mail on .test)"
public_tables=$(psql_db -tA -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public'")
[ "$public_tables" = "0" ] || fail "a table lives in public"

echo "== 7. flyway.toml lists the base locations one per line and never 04_demo"
listed=$(grep -c '"filesystem:' flyway.toml)
parsed=$(echo "$BASE_LOCATIONS" | tr ',' '\n' | grep -c '^filesystem:')
[ "$listed" = "$parsed" ] || fail "flyway.toml lists $listed locations but one per line yields $parsed (qone-infra reads it so)"
grep -q '04_demo"' flyway.toml && fail "04_demo must never be a location of flyway.toml"

echo "== 8. without the demo location (qa, main) a fresh database holds no demo people"
cleanup
$DC up -d identity-db --wait
migrate_plain migrate | tee /tmp/migrate-4.log
grep -q "Successfully applied" /tmp/migrate-4.log || fail "the migrate without the demo location applied nothing"
people=$(psql_db -tA -c "SELECT count(*) FROM identity.app_user")
[ "$people" = "0" ] || fail "expected no people outside develop, found $people"
demo=$(psql_db -tA -c "SELECT count(*) FROM identity.flyway_schema_history WHERE version = '007'")
[ "$demo" = "0" ] || fail "V007 (the demo people) was applied without the demo location"

echo "OK: qone-identity-db rebuilds from zero, applies nothing twice, undoes completely, rebuilds, validates, seeds idempotently, and holds the synthetic demo people only in develop"
