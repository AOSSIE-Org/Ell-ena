-- Hybrid ranking on top of HNSW cosine candidates.
-- Preserves rag_search / search_rag_by_resp_id names and original return columns.
-- Adds ranking metadata and a similarity floor before urgency/recency apply.
-- Drop prior signatures first: CREATE OR REPLACE cannot change RETURNS TABLE.

DROP FUNCTION IF EXISTS search_rag_by_resp_id(bigint, integer, double precision);
DROP FUNCTION IF EXISTS search_rag_by_resp_id(bigint, integer, real);
DROP FUNCTION IF EXISTS rag_search(vector, integer, double precision);
DROP FUNCTION IF EXISTS rag_search(vector, integer, real);

CREATE OR REPLACE FUNCTION rag_search(
    query_embedding vector(768),
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.30,
    candidate_count INT DEFAULT NULL
)
RETURNS TABLE (
    entity_type TEXT,
    entity_id UUID,
    title TEXT,
    content TEXT,
    similarity FLOAT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    meeting_date TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    priority TEXT,
    status TEXT,
    recency_score FLOAT,
    urgency_score FLOAT,
    final_score FLOAT
) AS $$
DECLARE
    pool INT;
    safe_match INT;
    semantic_weight CONSTANT FLOAT := 0.70;
    recency_weight CONSTANT FLOAT := 0.20;
    urgency_weight CONSTANT FLOAT := 0.10;
    half_life_days CONSTANT FLOAT := 21.0;
    max_pool CONSTANT INT := 50;
BEGIN
    -- Bound final top-k and candidate pool to avoid oversized scans.
    safe_match := LEAST(GREATEST(COALESCE(match_count, 5), 1), 25);
    pool := COALESCE(candidate_count, GREATEST(safe_match * 3, 9));
    pool := LEAST(GREATEST(pool, safe_match), max_pool);

    RETURN QUERY
    WITH candidates AS (
        (
            SELECT
                'meeting'::TEXT AS entity_type,
                m.id AS entity_id,
                m.title,
                m.meeting_summary_json::TEXT AS content,
                (1 - (m.summary_embedding <=> query_embedding))::FLOAT AS similarity,
                m.created_at,
                m.updated_at,
                m.meeting_date,
                NULL::TIMESTAMPTZ AS due_date,
                NULL::TEXT AS priority,
                NULL::TEXT AS status
            FROM meetings m
            WHERE m.summary_embedding IS NOT NULL
            ORDER BY m.summary_embedding <=> query_embedding
            LIMIT pool
        )
        UNION ALL
        (
            SELECT
                'task'::TEXT AS entity_type,
                t.id AS entity_id,
                t.title,
                t.description AS content,
                (1 - (t.description_embedding <=> query_embedding))::FLOAT AS similarity,
                t.created_at,
                t.updated_at,
                NULL::TIMESTAMPTZ AS meeting_date,
                t.due_date,
                NULL::TEXT AS priority,
                t.status
            FROM tasks t
            WHERE t.description_embedding IS NOT NULL
            ORDER BY t.description_embedding <=> query_embedding
            LIMIT pool
        )
        UNION ALL
        (
            SELECT
                'ticket'::TEXT AS entity_type,
                tk.id AS entity_id,
                tk.title,
                tk.description AS content,
                (1 - (tk.description_embedding <=> query_embedding))::FLOAT AS similarity,
                tk.created_at,
                tk.updated_at,
                NULL::TIMESTAMPTZ AS meeting_date,
                NULL::TIMESTAMPTZ AS due_date,
                tk.priority,
                tk.status
            FROM tickets tk
            WHERE tk.description_embedding IS NOT NULL
            ORDER BY tk.description_embedding <=> query_embedding
            LIMIT pool
        )
    ),
    scored AS (
        SELECT
            c.*,
            (
                EXP(
                    -GREATEST(
                        0.0,
                        EXTRACT(
                            EPOCH FROM (
                                NOW() - COALESCE(
                                    CASE
                                        WHEN c.entity_type = 'meeting'
                                            THEN COALESCE(
                                                c.meeting_date,
                                                c.updated_at,
                                                c.created_at
                                            )
                                        ELSE COALESCE(c.updated_at, c.created_at)
                                    END,
                                    NOW()
                                )
                            )
                        ) / 86400.0
                    ) / half_life_days
                )
            )::FLOAT AS recency_score,
            (
                CASE c.entity_type
                    WHEN 'meeting' THEN 0.0
                    WHEN 'task' THEN
                        CASE
                            WHEN c.status = 'completed' THEN 0.0
                            WHEN c.due_date IS NOT NULL AND c.due_date < NOW()
                                THEN 1.0
                            WHEN c.due_date IS NOT NULL
                                 AND c.due_date <= NOW() + INTERVAL '3 days'
                                THEN 0.85
                            WHEN c.due_date IS NOT NULL
                                 AND c.due_date <= NOW() + INTERVAL '7 days'
                                THEN 0.55
                            WHEN c.status = 'in_progress' THEN 0.45
                            WHEN c.status = 'todo' THEN 0.30
                            ELSE 0.10
                        END
                    WHEN 'ticket' THEN
                        CASE
                            WHEN c.status = 'resolved' THEN 0.0
                            ELSE
                                CASE LOWER(COALESCE(c.priority, 'medium'))
                                    WHEN 'high' THEN 1.0
                                    WHEN 'medium' THEN 0.50
                                    WHEN 'low' THEN 0.20
                                    ELSE 0.35
                                END
                                * CASE
                                    WHEN c.status IN ('open', 'in_progress')
                                        THEN 1.0
                                    ELSE 0.40
                                  END
                        END
                    ELSE 0.0
                END
            )::FLOAT AS urgency_score
        FROM candidates c
        WHERE c.similarity >= similarity_threshold
    )
    SELECT
        s.entity_type,
        s.entity_id,
        s.title,
        s.content,
        s.similarity,
        s.created_at,
        s.updated_at,
        s.meeting_date,
        s.due_date,
        s.priority,
        s.status,
        s.recency_score,
        s.urgency_score,
        (
            semantic_weight * s.similarity
            + recency_weight * s.recency_score
            + urgency_weight * s.urgency_score
        )::FLOAT AS final_score
    FROM scored s
    ORDER BY
        (
            semantic_weight * s.similarity
            + recency_weight * s.recency_score
            + urgency_weight * s.urgency_score
        ) DESC,
        s.similarity DESC
    LIMIT safe_match;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION search_rag_by_resp_id(
    resp_id BIGINT,
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.30,
    candidate_count INT DEFAULT NULL
)
RETURNS TABLE (
    entity_type TEXT,
    entity_id UUID,
    title TEXT,
    content TEXT,
    similarity FLOAT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ,
    meeting_date TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    priority TEXT,
    status TEXT,
    recency_score FLOAT,
    urgency_score FLOAT,
    final_score FLOAT
) AS $$
DECLARE
    api_response JSONB;
    query_embedding vector(768);
BEGIN
    api_response := get_embedding_response(resp_id);
    query_embedding := extract_embedding(api_response);

    RETURN QUERY
    SELECT * FROM rag_search(
        query_embedding,
        match_count,
        similarity_threshold,
        candidate_count
    );
END;
$$ LANGUAGE plpgsql;
