-- By now every table of the domain is gone (U003..U009); only flyway_schema_history remains
-- in the schema, so dropping it with CASCADE removes the migration history as well.
DROP SCHEMA IF EXISTS identity CASCADE;
