-- app_user: the people of Qampus (06-data/models.md, schema identity). `user` is a reserved
-- word, hence app_user. The password hash is PBKDF2-HMAC-SHA256 as salt$hex and never leaves
-- this database. SERVICE exists only in tokens, never as a row.
CREATE TABLE identity.app_user (
    id            uuid        NOT NULL DEFAULT gen_random_uuid(),
    email         text        NOT NULL,
    name          text        NOT NULL,
    password_hash text        NOT NULL,
    role          text        NOT NULL,
    student_code  text        NULL,
    program       text        NULL,
    semester      integer     NULL,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT pk_app_user              PRIMARY KEY (id),
    CONSTRAINT chk_app_user_email       CHECK (length(email) <= 120 AND email = lower(email)),
    CONSTRAINT chk_app_user_name        CHECK (length(name) BETWEEN 2 AND 120),
    CONSTRAINT chk_app_user_role        CHECK (role IN ('STUDENT', 'PROFESSOR', 'ADMIN')),
    CONSTRAINT chk_app_user_student_code CHECK (student_code IS NULL OR student_code ~ '^[0-9]{6,20}$'),
    CONSTRAINT chk_app_user_program     CHECK (program IS NULL OR length(program) <= 80),
    CONSTRAINT chk_app_user_semester    CHECK (semester IS NULL OR semester BETWEEN 1 AND 12),
    -- A student carries a code; nobody else does.
    CONSTRAINT chk_app_user_student_fields CHECK ((role = 'STUDENT') = (student_code IS NOT NULL))
);

COMMENT ON TABLE  identity.app_user IS 'People of Qampus: students, professors, admins. The sub of every user token.';
COMMENT ON COLUMN identity.app_user.password_hash IS 'PBKDF2-HMAC-SHA256, 200000 iterations, salt$hex; never serialized.';
