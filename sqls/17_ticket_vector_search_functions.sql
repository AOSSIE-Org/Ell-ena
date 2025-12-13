-- Vector similarity search functions for tickets
-- Provides semantic search capabilities using cosine distance on ticket embeddings

-- Function to search tickets by embedding vector
-- Returns top-k most similar tickets based on cosine similarity
CREATE OR REPLACE FUNCTION get_similar_tickets(
    query_embedding vector(768),
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.0
)
RETURNS TABLE (
    ticket_id UUID,
    ticket_number TEXT,
    title TEXT,
    description TEXT,
    priority TEXT,
    category TEXT,
    status TEXT,
    approval_status TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    assigned_to UUID,
    created_by UUID,
    team_id UUID,
    similarity FLOAT
) AS $$
BEGIN
    RAISE LOG 'Querying tickets with embedding, match_count: %, threshold: %', match_count, similarity_threshold;

    RETURN QUERY
    SELECT
        tk.id AS ticket_id,
        tk.ticket_number,
        tk.title,
        tk.description,
        tk.priority,
        tk.category,
        tk.status,
        tk.approval_status,
        tk.created_at,
        tk.assigned_to,
        tk.created_by,
        tk.team_id,
        1 - (tk.description_embedding <=> query_embedding) AS similarity
    FROM tickets tk
    WHERE 
        tk.description_embedding IS NOT NULL
        AND (1 - (tk.description_embedding <=> query_embedding)) >= similarity_threshold
        AND tk.team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    ORDER BY tk.description_embedding <=> query_embedding
    LIMIT match_count;

    RAISE LOG 'get_similar_tickets completed';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search tickets by text query via Edge Function
-- This function queues embedding generation and waits for the response
CREATE OR REPLACE FUNCTION search_tickets_by_query(
    query_text TEXT,
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.0
)
RETURNS TABLE (
    ticket_id UUID,
    ticket_number TEXT,
    title TEXT,
    description TEXT,
    priority TEXT,
    category TEXT,
    status TEXT,
    approval_status TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    assigned_to UUID,
    created_by UUID,
    team_id UUID,
    similarity FLOAT
) AS $$
DECLARE
    resp_id BIGINT;
    api_response JSONB;
    query_embedding vector(768);
BEGIN
    RAISE LOG 'Starting search_tickets_by_query for query: %', query_text;

    -- Step 1: Queue embedding generation
    resp_id := queue_embedding(query_text);
    RAISE LOG 'Embedding queued with resp_id: %', resp_id;

    -- Step 2: Wait for and retrieve embedding response
    api_response := get_embedding_response(resp_id);
    RAISE LOG 'Embedding response received';

    -- Step 3: Extract vector from response
    query_embedding := extract_embedding(api_response);

    -- Step 4: Return similar tickets
    RETURN QUERY
    SELECT * FROM get_similar_tickets(query_embedding, match_count, similarity_threshold);
    
    RAISE LOG 'search_tickets_by_query completed';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate embeddings for existing tickets without embeddings
-- This is used for backfilling embeddings on existing data
CREATE OR REPLACE FUNCTION generate_missing_ticket_embeddings()
RETURNS TABLE (
    ticket_id UUID,
    embedding_generated BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    ticket_record RECORD;
    resp_id BIGINT;
    api_response JSONB;
    embedding_vec vector(768);
    combined_text TEXT;
BEGIN
    RAISE LOG 'Starting generation of missing ticket embeddings';

    FOR ticket_record IN 
        SELECT id, title, description 
        FROM tickets 
        WHERE description_embedding IS NULL
    LOOP
        BEGIN
            -- Combine title and description for better semantic representation
            combined_text := ticket_record.title || '. ' || COALESCE(ticket_record.description, '');
            
            -- Queue embedding generation
            resp_id := queue_embedding(combined_text);
            
            -- Wait for response
            api_response := get_embedding_response(resp_id);
            
            -- Extract embedding
            embedding_vec := extract_embedding(api_response);
            
            -- Update ticket with embedding
            UPDATE tickets 
            SET description_embedding = embedding_vec 
            WHERE id = ticket_record.id;
            
            RETURN QUERY SELECT ticket_record.id, TRUE, NULL::TEXT;
            
            RAISE LOG 'Generated embedding for ticket: %', ticket_record.id;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to generate embedding for ticket %: %', ticket_record.id, SQLERRM;
            RETURN QUERY SELECT ticket_record.id, FALSE, SQLERRM;
        END;
    END LOOP;

    RAISE LOG 'Completed generation of missing ticket embeddings';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
