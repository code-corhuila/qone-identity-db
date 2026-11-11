#!/usr/bin/env sh
# Guard of the synthetic seed identities (code-corhuila/qone-docs#55), no Docker needed:
#   - every e-mail written in a migration ends in .test (reserved TLD, RFC 2606);
#   - no migration carries a password-hash literal ('pbkdf2_...', '$pbkdf2-...' or the salt$hex of PBKDF2):
#     hashes are computed from the environment at seed time, never versioned.
# Usage: sh scripts/check-seed-identities.sh   (db-ci and scripts/rebuild-check.sh run it)
set -eu
cd "$(dirname "$0")/.."
status=0
emails=$(grep -rhoE "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+" migrations --include='*.sql' | grep -vE "\.test$" || true)
if [ -n "$emails" ]; then
  echo "FAIL: e-mail(s) outside the .test TLD in migrations:" >&2
  echo "$emails" | sort -u >&2
  status=1
fi
q="'"
hashes=$(grep -rlE "${q}([\$]?pbkdf2[-_:\$][^${q} ]+|[0-9a-f]{32}[\$][0-9a-f]{64})${q}" migrations --include='*.sql' || true)
if [ -n "$hashes" ]; then
  echo "FAIL: password-hash literal in (value not printed):" >&2
  echo "$hashes" >&2
  status=1
fi
[ "$status" = "0" ] && echo "OK: seed e-mails are on .test and no migration holds a password hash"
exit "$status"
