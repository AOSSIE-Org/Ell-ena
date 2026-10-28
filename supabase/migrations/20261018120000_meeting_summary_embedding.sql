CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE meetings
  ADD COLUMN IF NOT EXISTS summary_embedding vector(768);
