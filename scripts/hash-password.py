#!/usr/bin/env python3
"""Prints the PBKDF2-HMAC-SHA256 hash (200,000 iterations, 16-byte salt, `salt$hex`) of a
password, the format qone-identity-api verifies. Standard library only.
    python scripts/hash-password.py "$DEMO_PASSWORD"
"""
import hashlib
import secrets
import sys

ITERATIONS = 200_000

if len(sys.argv) != 2 or not sys.argv[1]:
    sys.exit("usage: hash-password.py <password>")
salt = secrets.token_hex(16)
digest = hashlib.pbkdf2_hmac("sha256", sys.argv[1].encode("utf-8"), salt.encode("utf-8"), ITERATIONS).hex()
print(f"{salt}${digest}")
