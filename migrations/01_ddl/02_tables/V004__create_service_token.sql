-- service_token: the tokens issued to qone-workflow, qone-worker and qone-advisor-api (ID-07).
-- Only the SHA-256 of the JWT is kept; the value is shown once at issue.
CREATE TABLE identity.service_token (
    id         uuid        NOT NULL DEFAULT gen_random_uuid(),
    service    text        NOT NULL,
    token_hash text        NOT NULL,
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_service_token          PRIMARY KEY (id),
    CONSTRAINT chk_service_token_service CHECK (service IN ('qone-workflow', 'qone-worker', 'qone-advisor-api')),
    CONSTRAINT chk_service_token_hash    CHECK (length(token_hash) = 64)
);

COMMENT ON TABLE identity.service_token IS 'Service tokens (role SERVICE, sub = service name); metadata only, the JWT is returned once.';
