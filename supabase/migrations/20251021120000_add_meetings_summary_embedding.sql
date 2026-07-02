-- Corrective migration: summary_embedding is referenced by vector search functions
-- (20251021090000) and generate-embeddings, but was never added in prior migrations.

ALTER TABLE meetings
    ADD COLUMN IF NOT EXISTS summary_embedding vector(768);

CREATE INDEX IF NOT EXISTS idx_meetings_summary_embedding
    ON meetings
    USING hnsw (summary_embedding vector_cosine_ops)
    WHERE summary_embedding IS NOT NULL;
