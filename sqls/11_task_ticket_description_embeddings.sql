-- Mirrors supabase/migrations/20260717120000_task_ticket_description_embeddings.sql
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS description_embedding vector(768);

ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS description_embedding vector(768);
