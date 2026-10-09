-- Mirrors supabase/migrations/20260729010000_hnsw_embedding_indexes.sql
-- Week 12: HNSW indexes for cosine vector similarity search.

CREATE EXTENSION IF NOT EXISTS vector;

CREATE INDEX IF NOT EXISTS meetings_summary_embedding_hnsw_idx
  ON meetings
  USING hnsw (summary_embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS tasks_description_embedding_hnsw_idx
  ON tasks
  USING hnsw (description_embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS tickets_description_embedding_hnsw_idx
  ON tickets
  USING hnsw (description_embedding vector_cosine_ops);
