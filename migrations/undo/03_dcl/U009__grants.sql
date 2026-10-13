REVOKE ALL ON ALL TABLES IN SCHEMA identity FROM identity_writer;
REVOKE ALL ON ALL TABLES IN SCHEMA identity FROM identity_reader;
REVOKE USAGE ON SCHEMA identity FROM identity_reader, identity_writer;
