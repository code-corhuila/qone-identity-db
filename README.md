# qone-identity-db

> identity bounded context: database (schema, seeds, migrations)

Part of the **Qampus (Quorum One)** distributed system — team `quorum-one`, Grupo 1.
Governance and documentation live in [`qone-docs`](https://github.com/code-corhuila/qone-docs).

## Purpose

The database of the **identity** domain (course norm 5.2, Annex A): its own PostgreSQL 16
instance, the schema `identity` and the migrations that build it. `qone-identity-api` consumes
this structure and never versions it; no other service connects here (ADR-006, norm 7.3): the
users table is readable only by identity. The tool is **Flyway Community** (ADR-007): one SQL
file, one version number, and a mirror `U` script per version.

Specification: `06-data/models.md` (schema `identity`), `06-data/modeling-conventions.md`,
`06-data/migration-strategy.md`, `07-api/authentication.md` in `qone-docs`. Story:
`code-corhuila/qone-docs#35` (HU-AUT-001).

## Schema

| Table | What it keeps | Rules the database enforces |
|---|---|---|
| `app_user` | the people: e-mail, name, PBKDF2 password hash, role, student fields | e-mail unique and lower-case; role in `STUDENT`, `PROFESSOR`, `ADMIN` (`SERVICE` exists only in tokens); a student has a code and nobody else does; code digits 6 to 20, unique |
| `service_token` | the metadata of the tokens issued to `qone-workflow`, `qone-worker`, `qone-advisor-api` | the JWT itself is returned once; only its SHA-256 is kept, unique |
| `idempotency_key` | the `Idempotency-Key` of every registration and service token (norm 5.3.8) | key of 8 to 128 characters |

Roles `identity_reader` and `identity_writer` are `NOLOGIN`; `qone-infra` creates the login
users from secrets.

## Seed and the demo password

`02_dml/V007__seed_app_user.sql` inserts the nine people of the demo with the ids the portals'
fixtures use. **No password hash is written in the repository**: the seed carries the Flyway
placeholder `${demo_password_hash}`, replaced at migration time with
`FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH`, which `qone-infra` computes from the demo password of
its `.env`:

```bash
export FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH=$(python scripts/hash-password.py "$DEMO_PASSWORD")
```

`scripts/hash-password.py` is the standard-library PBKDF2-HMAC-SHA256 (200,000 iterations,
16-byte salt, `salt$hex`) that `qone-identity-api` verifies.

## Layout

```
migrations/
├── 01_ddl/   00_extensions · 01_schemas · 02_tables · 04_alter · 05_indexes   (V001..V006)
├── 02_dml/   seed as upserts with the password placeholder                    (V007)
├── 03_dcl/   roles and grants                                                 (V008, V009)
├── 04_tcl/   recorded one-off recoveries, never automatic
└── undo/     U001..U009, one per V, same relative path
flyway.toml   the locations, in order; undo/ is not one of them
deploy/       the instance and the Flyway runner that qone-infra includes
scripts/      rebuild-check.sh (what db-ci runs), hash-password.py
```

## How to run it

```bash
cp .env.example .env            # set IDENTITY_DB_PASSWORD and the placeholder; .env is ignored by git
docker network create platform  # once; qone-infra creates it in the full platform
docker compose --env-file .env -f deploy/compose.yml up -d identity-db
docker compose --env-file .env -f deploy/compose.yml --profile migrate run --rm identity-db-migrate
sh scripts/rebuild-check.sh     # the Annex A check db-ci runs on every pull request
```

## Branching

Three permanent branches. **None of them accepts a direct commit** — you enter through a child
branch and leave through a Pull Request.

```
develop  <--PR--  feat/... fix/... chore/...
qa       <--PR--  qa/...
main     <--PR--  release/...  hotfix/...
```

Promotion happens **by re-application** (`git cherry-pick -x`), never by merging one permanent
branch into another: `merge develop -> qa` and `merge qa -> main` do not exist in this model.

`main` requires **1 approval from `ariel5253`**. On `develop` and `qa` the team sets its own review
rule.

Full policy: `00-governance/branching-policy.md` in `qone-docs`.
