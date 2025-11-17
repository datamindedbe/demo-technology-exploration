CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS ingest_log (
    job_id TEXT PRIMARY KEY,
    status TEXT
);

CREATE TABLE IF NOT EXISTS google_drive_files (
    id TEXT PRIMARY KEY,
    name TEXT,
    mime_type TEXT,
    modified_time TIMESTAMPTZ,
    web_view_link TEXT,
    description TEXT,
    content TEXT,
    embedding vector(384)
); 