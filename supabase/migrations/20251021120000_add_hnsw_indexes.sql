CREATE INDEX IF NOT EXISTS idx_tasks_embedding
ON tasks USING hnsw (description_embedding vector_cosine_ops);

CREATE INDEX IF NOT EXISTS idx_tickets_embedding
ON tickets USING hnsw (description_embedding vector_cosine_ops);
