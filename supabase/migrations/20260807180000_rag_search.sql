-- Week 13: unified semantic retrieval across meetings, tasks, and tickets.
-- Mirrors the meeting vector search pattern in 20251021090000_meeting_vector_search.sql.
-- Does not modify existing RPCs or embedding infrastructure.

CREATE OR REPLACE FUNCTION rag_search(
    query_embedding vector(768),
    match_count INT DEFAULT 3,
    similarity_threshold FLOAT DEFAULT 0.0
)
RETURNS TABLE (
    entity_type TEXT,
    entity_id UUID,
    title TEXT,
    content TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RAISE LOG 'Querying meetings, tasks, and tickets with a given embedding';

    RETURN QUERY
    SELECT
        ranked.entity_type,
        ranked.entity_id,
        ranked.title,
        ranked.content,
        ranked.similarity
    FROM (
        (
            SELECT
                'meeting'::TEXT AS entity_type,
                m.id AS entity_id,
                m.title,
                m.meeting_summary_json::TEXT AS content,
                1 - (m.summary_embedding <=> query_embedding) AS similarity
            FROM meetings m
            WHERE m.summary_embedding IS NOT NULL
            ORDER BY m.summary_embedding <=> query_embedding
            LIMIT match_count
        )

        UNION ALL

        (
            SELECT
                'task'::TEXT AS entity_type,
                t.id AS entity_id,
                t.title,
                t.description AS content,
                1 - (t.description_embedding <=> query_embedding) AS similarity
            FROM tasks t
            WHERE t.description_embedding IS NOT NULL
            ORDER BY t.description_embedding <=> query_embedding
            LIMIT match_count
        )

        UNION ALL

        (
            SELECT
                'ticket'::TEXT AS entity_type,
                tk.id AS entity_id,
                tk.title,
                tk.description AS content,
                1 - (tk.description_embedding <=> query_embedding) AS similarity
            FROM tickets tk
            WHERE tk.description_embedding IS NOT NULL
            ORDER BY tk.description_embedding <=> query_embedding
            LIMIT match_count
        )
    ) ranked
    WHERE ranked.similarity >= similarity_threshold
    ORDER BY ranked.similarity DESC
    LIMIT match_count;

    RAISE LOG 'rag_search completed';
END;
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION search_rag_by_resp_id(
    resp_id BIGINT,
    match_count INT DEFAULT 3,
    similarity_threshold FLOAT DEFAULT 0.0
)
RETURNS TABLE (
    entity_type TEXT,
    entity_id UUID,
    title TEXT,
    content TEXT,
    similarity FLOAT
) AS $$
DECLARE
    api_response JSONB;
    query_embedding vector(768);
BEGIN
    RAISE LOG 'Starting search_rag_by_resp_id for resp_id: %', resp_id;

    -- Step 1: Wait for response
    api_response := get_embedding_response(resp_id);
    RAISE LOG 'Embedding response received: %', api_response;

    -- Step 2: Extract vector
    query_embedding := extract_embedding(api_response);

    -- Step 3: Return similar entities
    RETURN QUERY
    SELECT * FROM rag_search(query_embedding, match_count, similarity_threshold);

    RAISE LOG 'search_rag_by_resp_id completed';
END;
$$ LANGUAGE plpgsql;
