-- Mirrors supabase/migrations/20261018120000_meeting_summary_embedding.sql
CREATE EXTENSION IF NOT EXISTS vector;

ALTER TABLE meetings
  ADD COLUMN IF NOT EXISTS summary_embedding vector(768);
