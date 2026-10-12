-- Roles carry permissions and have no password (Annex A rule 10): NOLOGIN. The login users
-- that qone-identity-api connects with are created by qone-infra from secrets.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'identity_reader') THEN
        CREATE ROLE identity_reader NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'identity_writer') THEN
        CREATE ROLE identity_writer NOLOGIN;
    END IF;
END
$$;
