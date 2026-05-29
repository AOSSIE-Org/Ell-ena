CREATE OR REPLACE FUNCTION get_similar_tasks(
    query_embedding vector(768),
    match_count INT DEFAULT 3
)
RETURNS TABLE (
    task_id UUID,
    title TEXT,
    description TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id AS task_id,
        t.title,
        t.description,
        1 - (t.description_embedding <=> query_embedding) AS similarity
    FROM tasks t
    WHERE t.description_embedding IS NOT NULL
    ORDER BY t.description_embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_similar_tickets(
    query_embedding vector(768),
    match_count INT DEFAULT 3
)
RETURNS TABLE (
    ticket_id UUID,
    title TEXT,
    description TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        tk.id AS ticket_id,
        tk.title,
        tk.description,
        1 - (tk.description_embedding <=> query_embedding) AS similarity
    FROM tickets tk
    WHERE tk.description_embedding IS NOT NULL
    ORDER BY tk.description_embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;
