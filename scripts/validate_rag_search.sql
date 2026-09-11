-- Validate hybrid rag_search (cosine candidates + ranking metadata).
-- Prerequisites:
--   - migrations through 20260822130000_rag_hybrid_ranking.sql applied
--   - HNSW indexes present
--   - some meetings/tasks/tickets with non-null embeddings

-- ---------------------------------------------------------------------------
-- 1) Confirm RPCs exist
-- ---------------------------------------------------------------------------
SELECT proname
FROM pg_proc
WHERE proname IN ('rag_search', 'search_rag_by_resp_id')
ORDER BY proname;

-- ---------------------------------------------------------------------------
-- 2) Sample retrieval using an existing embedding as the query vector
-- ---------------------------------------------------------------------------
SELECT *
FROM rag_search(
  COALESCE(
    (SELECT summary_embedding FROM meetings WHERE summary_embedding IS NOT NULL LIMIT 1),
    (SELECT description_embedding FROM tasks WHERE description_embedding IS NOT NULL LIMIT 1),
    (SELECT description_embedding FROM tickets WHERE description_embedding IS NOT NULL LIMIT 1)
  ),
  5,     -- match_count
  0.30,  -- similarity_threshold
  15     -- candidate_count
);

-- Expect columns: entity_type, entity_id, title, content, similarity,
-- created_at, updated_at, meeting_date, due_date, priority, status,
-- recency_score, urgency_score, final_score
-- and similarity >= 0.30 for every returned row.

-- ---------------------------------------------------------------------------
-- 3) EXPLAIN ANALYZE — per-entity branches should be able to use HNSW
-- ---------------------------------------------------------------------------
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

-- Look for: Index Scan using meetings_summary_embedding_hnsw_idx /
-- tasks_description_embedding_hnsw_idx / tickets_description_embedding_hnsw_idx
-- (Seq Scan is possible on very small tables.)

-- ---------------------------------------------------------------------------
-- 4) Manual query checklist (run via Flutter chat or queue_embedding path)
-- ---------------------------------------------------------------------------
-- Query: "login issue"
--   Expect: tickets/tasks mentioning login, auth, sign-in; maybe meetings about auth.
--   Why: semantic overlap with authentication failure language.
--   Ordering: highest final_score among rows above the similarity floor.
--
-- Query: "authentication"
--   Expect: auth-related tickets/tasks; meetings discussing auth if embedded.
--   Why: close to login/security vocabulary in embeddings.
--
-- Query: "dashboard"
--   Expect: UI/feature tasks or tickets about dashboard; related meeting notes.
--   Why: product-area terms in title/description/summary embeddings.
--
-- Query: "sprint planning"
--   Expect: meetings about planning/sprint; related tasks.
--   Why: meeting summaries often encode planning language.
--
-- Query: "dark mode"
--   Expect: feature tickets/tasks about theme/dark mode.
--   Why: distinctive UI feature phrasing.
--
-- For live path validation from SQL (requires working get-embedding):
--   SELECT search_rag_by_resp_id(queue_embedding('login issue'), 5, 0.30);
--   SELECT search_rag_by_resp_id(queue_embedding('authentication'), 5, 0.30);
--   SELECT search_rag_by_resp_id(queue_embedding('dashboard'), 5, 0.30);
--   SELECT search_rag_by_resp_id(queue_embedding('sprint planning'), 5, 0.30);
--   SELECT search_rag_by_resp_id(queue_embedding('dark mode'), 5, 0.30);
