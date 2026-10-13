-- The nine people of the demo (06-data, ADR-009): the same ids the portals' fixtures use.
-- The password hash is NOT written here: Flyway replaces ${demo_password_hash} with the value of
-- FLYWAY_PLACEHOLDERS_DEMO_PASSWORD_HASH, computed from the demo password of the .env with
-- scripts/hash-password.py (migration-strategy.md rule 5). Upsert on the id (Annex A rule 11).
INSERT INTO identity.app_user (id, email, name, password_hash, role, student_code, program, semester, created_at, updated_at)
VALUES
    ('11111111-1111-4111-8111-111111111111', 'laura.gomez@uni.edu.co',      'Laura Gómez',        '${demo_password_hash}', 'STUDENT',   '202110342', 'Ingeniería de Software', 6, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111112', 'santiago.rojas@uni.edu.co',   'Santiago Rojas',     '${demo_password_hash}', 'STUDENT',   '202201983', 'Ingeniería de Software', 5, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111113', 'maria.cabrera@uni.edu.co',    'María José Cabrera', '${demo_password_hash}', 'STUDENT',   '202111205', 'Ingeniería de Software', 6, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111114', 'andres.pineda@uni.edu.co',    'Andrés Pineda',      '${demo_password_hash}', 'STUDENT',   '202008761', 'Ingeniería de Software', 7, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('11111111-1111-4111-8111-111111111115', 'valentina.suarez@uni.edu.co', 'Valentina Suárez',   '${demo_password_hash}', 'STUDENT',   '202009114', 'Ingeniería de Software', 7, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('22222222-2222-4222-8222-222222222221', 'carlos.ramirez@uni.edu.co',   'Carlos Ramírez',     '${demo_password_hash}', 'PROFESSOR', NULL, NULL, NULL, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('22222222-2222-4222-8222-222222222222', 'ana.torres@uni.edu.co',       'Ana Torres',         '${demo_password_hash}', 'PROFESSOR', NULL, NULL, NULL, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('22222222-2222-4222-8222-222222222223', 'jorge.medina@uni.edu.co',     'Jorge Medina',       '${demo_password_hash}', 'PROFESSOR', NULL, NULL, NULL, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z'),
    ('33333333-3333-4333-8333-333333333331', 'admin@uni.edu.co',            'Patricia Mora',      '${demo_password_hash}', 'ADMIN',     NULL, NULL, NULL, '2026-08-01T12:00:00Z', '2026-08-01T12:00:00Z')
ON CONFLICT (id) DO UPDATE SET
    email         = EXCLUDED.email,
    name          = EXCLUDED.name,
    password_hash = EXCLUDED.password_hash,
    role          = EXCLUDED.role,
    student_code  = EXCLUDED.student_code,
    program       = EXCLUDED.program,
    semester      = EXCLUDED.semester,
    updated_at    = EXCLUDED.updated_at;
