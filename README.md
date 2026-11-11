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
| `idempotency_key` | the `Idempotency-Key` of every registration and service token (norm 5.3.8), its owner and the SHA-256 of the request that used it | key of 8 to 128 characters, unique **per owner** (`owner_id`: the token subject, `anonymous` for the public registration; `code-corhuila/qone-docs#55`); `request_hash` is 64 hex characters |

Roles `identity_reader` and `identity_writer` are `NOLOGIN`; `qone-infra` creates the login
users from secrets.

## Demo people: develop only

`04_demo/V007__seed_app_user.sql` inserts the **eight** demo people with the ids the portals'
fixtures use, all synthetic (`code-corhuila/qone-docs#55`): `Estudiante Demo 01`..`05`
(`estudiante.01@qampus.test`.., codes `2099000001`..`2099000005`) and `Profesor Demo 01`..`03`
(`profesor.01@qampus.test`..), on the reserved `.test` TLD (RFC 2606). **There is no ADMIN row**:
`qone-identity-api` creates the ADMIN (`33333333-3333-4333-8333-333333333331`) on start from
`BOOTSTRAP_ADMIN_EMAIL` and `BOOTSTRAP_ADMIN_PASSWORD`, and never overwrites an existing one.

**The demo people exist only in develop.** `migrations/04_demo` is not a location of
`flyway.toml`. In develop, `qone-infra`'s `scripts/migrate.sh` reads the locations of
`flyway.toml` and runs the identity runner with `-locations=<those>,filesystem:migrations/04_demo`
(its `IDENTITY_DEMO_LOCATION`); in qa and main it runs the plain list, so their databases hold no
demo people. Keep one location per line in `flyway.toml`: that is how the list is read.
`scripts/rebuild-check.sh` proves both paths (steps 1-6 with the demo location, step 8 without).

| Environment (`APP_ENV`) | Identity runner locations | People after migrate |
|---|---|---|
| develop | `flyway.toml` + `filesystem:migrations/04_demo` | the 8 demo people (+ the ADMIN of the bootstrap) |
| qa, main | `flyway.toml` | none (only the ADMIN of the bootstrap) |

By hand, in develop:

```bash
docker compose --env-file .env -f deploy/compose.yml --profile tooling run --rm identity-db-migrate   -locations=filesystem:migrations/01_ddl,filesystem:migrations/02_dml,filesystem:migrations/03_dcl,filesystem:migrations/04_tcl,filesystem:migrations/04_demo migrate
```

**No password hash is written in the repository**: the seed carries the Flyway placeholder
`${demo_password_hash}`, replaced at migration time with `FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH`,
which `qone-infra` computes from the `DEMO_PASSWORD` of `qone-infra/.env`:

```bash
export FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH=$(python scripts/hash-password.py "$DEMO_PASSWORD")
```

`scripts/hash-password.py` is the standard-library PBKDF2-HMAC-SHA256 (200,000 iterations,
16-byte salt, `salt$hex`) that `qone-identity-api` verifies. `scripts/check-seed-identities.sh`
(db-ci, and step 0 of the rebuild check) fails on any e-mail outside `.test` or any
password-hash literal in a migration.

The move and the renaming changed V007 in place, a decided exception to "a merged version is
immutable": its Flyway checksum changed, so a machine that already applied it runs
`sh scripts/down.sh --volumes` once in `qone-infra` (every environment is local) and brings the
platform up again.

## Layout

```
migrations/
├── 01_ddl/   00_extensions · 01_schemas · 02_tables · 04_alter · 05_indexes   (V001..V006, V010)
├── 02_dml/   data patches as upserts (empty: the only seed is the demo, below)
├── 03_dcl/   roles and grants                                                 (V008, V009)
├── 04_tcl/   recorded one-off recoveries, never automatic
├── 04_demo/  develop only: the demo people, password placeholder              (V007)
└── undo/     U001..U010, one per V, same relative path
flyway.toml   the locations, one per line; neither undo/ nor 04_demo/ is one of them
deploy/       the instance and the Flyway runner that qone-infra includes
scripts/      rebuild-check.sh (what db-ci runs), check-seed-identities.sh, hash-password.py
```

## How to run it

```bash
cp .env.example .env            # set IDENTITY_DB_PASSWORD (and, for develop, the placeholder); .env is ignored by git
docker network create platform  # once; qone-infra creates it in the full platform
docker compose --env-file .env -f deploy/compose.yml up -d identity-db
docker compose --env-file .env -f deploy/compose.yml --profile tooling run --rm identity-db-migrate
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
