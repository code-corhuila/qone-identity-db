-- The eight demo people of develop (06-data, ADR-009): synthetic identities on the reserved
-- .test TLD (RFC 2606), with the ids the portals' fixtures use. Applied only in develop: 04_demo
-- is not in flyway.toml; qone-infra adds it to the runner's -locations when APP_ENV=develop. The
-- ADMIN is not seeded: qone-identity-api creates it on start from BOOTSTRAP_ADMIN_EMAIL/PASSWORD.
-- The password hash is NOT written here: Flyway replaces ${demo_password_hash} with the value of
-- FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH, computed from the DEMO_PASSWORD of qone-infra/.env with
-- scripts/hash-password.py (migration-strategy.md rule 5). Upsert on the id (Annex A rule 11).
INSERT INTO identity.app_user (id, email, name, password_hash, role, student_code, program, semester, created_at, updated_at)
VALUES
    ('11111111-1111-4111-8111-111111111111', 'estudiante.01@qampus.test', 'Estudiante Demo 01', '${demo_password_hash}', 'STUDENT',   '2099000001', 'Ingeniería de Software', 6, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111112', 'estudiante.02@qampus.test', 'Estudiante Demo 02', '${demo_password_hash}', 'STUDENT',   '2099000002', 'Ingeniería de Software', 5, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111113', 'estudiante.03@qampus.test', 'Estudiante Demo 03', '${demo_password_hash}', 'STUDENT',   '2099000003', 'Ingeniería de Software', 6, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111114', 'estudiante.04@qampus.test', 'Estudiante Demo 04', '${demo_password_hash}', 'STUDENT',   '2099000004', 'Ingeniería de Software', 7, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111115', 'estudiante.05@qampus.test', 'Estudiante Demo 05', '${demo_password_hash}', 'STUDENT',   '2099000005', 'Ingeniería de Software', 7, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('22222222-2222-4222-8222-222222222221', 'profesor.01@qampus.test',   'Profesor Demo 01',   '${demo_password_hash}', 'PROFESSOR', NULL, NULL, NULL, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('22222222-2222-4222-8222-222222222222', 'profesor.02@qampus.test',   'Profesor Demo 02',   '${demo_password_hash}', 'PROFESSOR', NULL, NULL, NULL, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('22222222-2222-4222-8222-222222222223', 'profesor.03@qampus.test',   'Profesor Demo 03',   '${demo_password_hash}', 'PROFESSOR', NULL, NULL, NULL, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    email         = EXCLUDED.email,
    name          = EXCLUDED.name,
    password_hash = EXCLUDED.password_hash,
    role          = EXCLUDED.role,
    student_code  = EXCLUDED.student_code,
    program       = EXCLUDED.program,
    semester      = EXCLUDED.semester,
    updated_at    = EXCLUDED.updated_at;
