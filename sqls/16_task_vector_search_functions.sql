-- Vector similarity search functions for tasks
-- Provides semantic search capabilities using cosine distance on task embeddings

-- Function to search tasks by embedding vector
-- Returns top-k most similar tasks based on cosine similarity
CREATE OR REPLACE FUNCTION get_similar_tasks(
    query_embedding vector(768),
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.0
)
RETURNS TABLE (
    task_id UUID,
    title TEXT,
    description TEXT,
    status TEXT,
    approval_status TEXT,
    due_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE,
    assigned_to UUID,
    created_by UUID,
    team_id UUID,
    similarity FLOAT
) AS $$
BEGIN
    RAISE LOG 'Querying tasks with embedding, match_count: %, threshold: %', match_count, similarity_threshold;

    RETURN QUERY
    SELECT
        t.id AS task_id,
        t.title,
        t.description,
        t.status,
        t.approval_status,
        t.due_date,
        t.created_at,
        t.assigned_to,
        t.created_by,
        t.team_id,
        1 - (t.description_embedding <=> query_embedding) AS similarity
    FROM tasks t
    WHERE 
        t.description_embedding IS NOT NULL
        AND (1 - (t.description_embedding <=> query_embedding)) >= similarity_threshold
        AND t.team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    ORDER BY t.description_embedding <=> query_embedding
    LIMIT match_count;

    RAISE LOG 'get_similar_tasks completed';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search tasks by text query via Edge Function
-- This function queues embedding generation and waits for the response
CREATE OR REPLACE FUNCTION search_tasks_by_query(
    query_text TEXT,
    match_count INT DEFAULT 5,
    similarity_threshold FLOAT DEFAULT 0.0
)
RETURNS TABLE (
    task_id UUID,
    title TEXT,
    description TEXT,
    status TEXT,
    approval_status TEXT,
    due_date TIMESTAMP WITH TIME ZONE,
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
    RAISE LOG 'Starting search_tasks_by_query for query: %', query_text;

    -- Step 1: Queue embedding generation
    resp_id := queue_embedding(query_text);
    RAISE LOG 'Embedding queued with resp_id: %', resp_id;

    -- Step 2: Wait for and retrieve embedding response
    api_response := get_embedding_response(resp_id);
    RAISE LOG 'Embedding response received';

    -- Step 3: Extract vector from response
    query_embedding := extract_embedding(api_response);

    -- Step 4: Return similar tasks
    RETURN QUERY
    SELECT * FROM get_similar_tasks(query_embedding, match_count, similarity_threshold);
    
    RAISE LOG 'search_tasks_by_query completed';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate embeddings for existing tasks without embeddings
-- This is used for backfilling embeddings on existing data
CREATE OR REPLACE FUNCTION generate_missing_task_embeddings()
RETURNS TABLE (
    task_id UUID,
    embedding_generated BOOLEAN,
    error_message TEXT
) AS $$
DECLARE
    task_record RECORD;
    resp_id BIGINT;
    api_response JSONB;
    embedding_vec vector(768);
    combined_text TEXT;
BEGIN
    RAISE LOG 'Starting generation of missing task embeddings';

    FOR task_record IN 
        SELECT id, title, description 
        FROM tasks 
        WHERE description_embedding IS NULL
    LOOP
        BEGIN
            -- Combine title and description for better semantic representation
            combined_text := task_record.title || '. ' || COALESCE(task_record.description, '');
            
            -- Queue embedding generation
            resp_id := queue_embedding(combined_text);
            
            -- Wait for response
            api_response := get_embedding_response(resp_id);
            
            -- Extract embedding
            embedding_vec := extract_embedding(api_response);
            
            -- Update task with embedding
            UPDATE tasks 
            SET description_embedding = embedding_vec 
            WHERE id = task_record.id;
            
            RETURN QUERY SELECT task_record.id, TRUE, NULL::TEXT;
            
            RAISE LOG 'Generated embedding for task: %', task_record.id;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Failed to generate embedding for task %: %', task_record.id, SQLERRM;
            RETURN QUERY SELECT task_record.id, FALSE, SQLERRM;
        END;
    END LOOP;

    RAISE LOG 'Completed generation of missing task embeddings';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
