-- task/ticket description embeddings (vector 768).
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS description_embedding vector(768);

ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS description_embedding vector(768);
