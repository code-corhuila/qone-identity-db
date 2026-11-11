-- An Idempotency-Key belongs to whoever sent it (code-corhuila/qone-docs#55, F1). The key alone was
-- the primary key, so a replay by another caller got back a resource that was not theirs. The key
-- is now unique per owner: the subject of the token (the ADMIN user id that issues a service
-- token) or 'anonymous' for the public registration. The row also keeps the SHA-256 (hex) of the
-- canonical request that created the resource: the same owner and key with another request is
-- refused (422 IDEMPOTENCY_KEY_REUSED) instead of answered.
ALTER TABLE identity.idempotency_key
    ADD COLUMN owner_id     text,
    ADD COLUMN request_hash text;

-- Keys written before the scope. A registration had no caller: owner 'anonymous'. The admin who
-- issued a service token was not recorded: owner 'unknown', which no token subject is, so nobody
-- replays it. No request was fingerprinted: 64 zeros, which no request hashes to, so replaying an
-- old key is refused rather than trusted.
UPDATE identity.idempotency_key
   SET owner_id     = CASE resource_type WHEN 'app_user' THEN 'anonymous' ELSE 'unknown' END,
       request_hash = repeat('0', 64);

ALTER TABLE identity.idempotency_key
    ALTER COLUMN owner_id     SET NOT NULL,
    ALTER COLUMN request_hash SET NOT NULL,
    DROP CONSTRAINT pk_idempotency_key,
    ADD CONSTRAINT pk_idempotency_key               PRIMARY KEY (owner_id, key),
    ADD CONSTRAINT chk_idempotency_key_owner        CHECK (length(owner_id) BETWEEN 1 AND 128),
    ADD CONSTRAINT chk_idempotency_key_request_hash CHECK (request_hash ~ '^[0-9a-f]{64}$');

COMMENT ON COLUMN identity.idempotency_key.owner_id IS 'Who sent the key: the token subject, or anonymous for the public registration.';
COMMENT ON COLUMN identity.idempotency_key.request_hash IS 'SHA-256 (hex) of the canonical request that created the resource.';
