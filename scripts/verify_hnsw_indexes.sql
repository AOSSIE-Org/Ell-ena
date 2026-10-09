-- Week 12: Verify pgvector + HNSW indexes and that the planner can use them.
-- Run after applying supabase/migrations/20260729010000_hnsw_embedding_indexes.sql

-- 1) pgvector extension
SELECT
  extname,
  extversion
FROM pg_extension
WHERE extname = 'vector';

-- 2) HNSW index definitions (expect three rows)
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE indexname IN (
  'meetings_summary_embedding_hnsw_idx',
  'tasks_description_embedding_hnsw_idx',
  'tickets_description_embedding_hnsw_idx'
)
ORDER BY tablename, indexname;

-- 3) Confirm index access method is hnsw
SELECT
  c.relname AS index_name,
  a.amname AS access_method
FROM pg_class c
JOIN pg_am a ON a.oid = c.relam
WHERE c.relname IN (
  'meetings_summary_embedding_hnsw_idx',
  'tasks_description_embedding_hnsw_idx',
  'tickets_description_embedding_hnsw_idx'
)
ORDER BY c.relname;

-- 4) Planner check — meetings
-- Expect "Index Scan using meetings_summary_embedding_hnsw_idx" when enough
-- embedded rows exist; otherwise Seq Scan may still win on tiny datasets.
EXPLAIN (ANALYZE, BUFFERS)
SELECT m.id
FROM meetings m
CROSS JOIN LATERAL (
  SELECT summary_embedding AS query_embedding
  FROM meetings
  WHERE summary_embedding IS NOT NULL
  LIMIT 1
) q
WHERE m.summary_embedding IS NOT NULL
ORDER BY m.summary_embedding <=> q.query_embedding
LIMIT 5;

-- 5) Planner check — tasks
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.id
FROM tasks t
CROSS JOIN LATERAL (
  SELECT description_embedding AS query_embedding
  FROM tasks
  WHERE description_embedding IS NOT NULL
  LIMIT 1
) q
WHERE t.description_embedding IS NOT NULL
ORDER BY t.description_embedding <=> q.query_embedding
LIMIT 5;

-- 6) Planner check — tickets
EXPLAIN (ANALYZE, BUFFERS)
SELECT tk.id
FROM tickets tk
CROSS JOIN LATERAL (
  SELECT description_embedding AS query_embedding
  FROM tickets
  WHERE description_embedding IS NOT NULL
  LIMIT 1
) q
WHERE tk.description_embedding IS NOT NULL
ORDER BY tk.description_embedding <=> q.query_embedding
LIMIT 5;
