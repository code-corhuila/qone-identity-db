-- Nothing is deleted by the application (no soft delete in v2); keys are pruned by age.
GRANT USAGE ON SCHEMA identity TO identity_reader, identity_writer;

GRANT SELECT ON ALL TABLES IN SCHEMA identity TO identity_reader;

GRANT SELECT, INSERT, UPDATE ON identity.app_user        TO identity_writer;
GRANT SELECT, INSERT, UPDATE ON identity.service_token   TO identity_writer;
GRANT SELECT, INSERT, DELETE ON identity.idempotency_key TO identity_writer;
