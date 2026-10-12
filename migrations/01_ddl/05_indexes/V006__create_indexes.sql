-- Every index names the query it serves (Annex A rule 3; 06-data/modeling-conventions.md).
-- The e-mail is the login identity and unique (business key).
CREATE UNIQUE INDEX ux_app_user_email ON identity.app_user (email);
-- The student code is unique when present.
CREATE UNIQUE INDEX ux_app_user_student_code ON identity.app_user (student_code) WHERE student_code IS NOT NULL;
-- ID-05: users newest first, filtered by role.
CREATE INDEX ix_app_user_role_created_at ON identity.app_user (role, created_at DESC);
-- A token hash is looked up by identity-aware checks and is unique.
CREATE UNIQUE INDEX ux_service_token_token_hash ON identity.service_token (token_hash);
-- The pruner of idempotency keys reads by age.
CREATE INDEX ix_idempotency_key_created_at ON identity.idempotency_key (created_at);
