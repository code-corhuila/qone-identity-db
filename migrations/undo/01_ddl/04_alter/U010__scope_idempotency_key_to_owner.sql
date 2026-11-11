-- Undo of V010: one key for everyone again. Where two owners used the same key, only the oldest
-- row can stay under the old primary key; the others are dropped (a retry then creates again).
DELETE FROM identity.idempotency_key k
 USING identity.idempotency_key older
 WHERE older.key = k.key
   AND (older.created_at, older.owner_id) < (k.created_at, k.owner_id);

ALTER TABLE identity.idempotency_key
    DROP CONSTRAINT IF EXISTS chk_idempotency_key_request_hash,
    DROP CONSTRAINT IF EXISTS chk_idempotency_key_owner,
    DROP CONSTRAINT IF EXISTS pk_idempotency_key,
    DROP COLUMN IF EXISTS request_hash,
    DROP COLUMN IF EXISTS owner_id,
    ADD CONSTRAINT pk_idempotency_key PRIMARY KEY (key);
