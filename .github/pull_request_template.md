## User story

code-corhuila/qone-docs#NN

## What changes and why

## How it was tested

- [ ] `db-ci` green: migrate from zero, migrate again applies nothing, every `U` undoes, rebuild, validate, seed twice

## Promotion trail

Only towards `qa` or `main`: the re-applied commits, each with its `(cherry picked from commit <sha>)` line.

## Checklist

- [ ] No secrets, no `.env`, no `*.pem`, no password hash in a seed
- [ ] Every `V` has its `U`; no applied migration was edited
- [ ] Nothing in `public`; no reference to another domain's schema
- [ ] `06-data/models.md` in `qone-docs` describes this schema
