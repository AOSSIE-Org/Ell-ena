-- Week 12: Benchmark HNSW-backed cosine nearest-neighbor retrieval.
--
-- Run in the Supabase SQL Editor after applying the HNSW migration.
-- Requires at least one non-NULL embedding per table for a meaningful plan.
--
-- Look for:
--   - "Index Scan using ..._hnsw_idx" (desired) vs "Seq Scan"
--   - Planning Time / Execution Time
--
-- Tip: On tiny tables the planner may still prefer Seq Scan. Seed enough
-- rows with embeddings (hundreds+) before comparing plans.

-- ---------------------------------------------------------------------------
-- Meetings (mirrors get_similar_meetings distance ordering)
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
  m.id,
  m.title,
  1 - (m.summary_embedding <=> q.query_embedding) AS similarity
FROM meetings m
CROSS JOIN LATERAL (
  SELECT summary_embedding AS query_embedding
  FROM meetings
  WHERE summary_embedding IS NOT NULL
  LIMIT 1
) q
WHERE m.summary_embedding IS NOT NULL
ORDER BY m.summary_embedding <=> q.query_embedding
LIMIT 10;

-- ---------------------------------------------------------------------------
-- Tasks
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
  t.id,
  t.title,
  1 - (t.description_embedding <=> q.query_embedding) AS similarity
FROM tasks t
CROSS JOIN LATERAL (
  SELECT description_embedding AS query_embedding
  FROM tasks
  WHERE description_embedding IS NOT NULL
  LIMIT 1
) q
WHERE t.description_embedding IS NOT NULL
ORDER BY t.description_embedding <=> q.query_embedding
LIMIT 10;

-- ---------------------------------------------------------------------------
-- Tickets
-- ---------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT
  tk.id,
  tk.title,
  1 - (tk.description_embedding <=> q.query_embedding) AS similarity
FROM tickets tk
CROSS JOIN LATERAL (
  SELECT description_embedding AS query_embedding
  FROM tickets
  WHERE description_embedding IS NOT NULL
  LIMIT 1
) q
WHERE tk.description_embedding IS NOT NULL
ORDER BY tk.description_embedding <=> q.query_embedding
LIMIT 10;
