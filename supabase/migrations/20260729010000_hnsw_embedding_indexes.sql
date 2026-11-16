-- Week 12: HNSW indexes for cosine vector similarity search.
-- Requires existing columns:
--   meetings.summary_embedding
--   tasks.description_embedding
--   tickets.description_embedding
-- Idempotent: safe to run once (CREATE INDEX IF NOT EXISTS).

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
