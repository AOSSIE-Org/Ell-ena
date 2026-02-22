-- Ensure required extensions exist
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Generic function to process missing embeddings
CREATE OR REPLACE FUNCTION process_missing_embeddings(
    p_table TEXT,
    p_entity_type TEXT,
    p_limit INT DEFAULT 50
)
RETURNS void AS $$
DECLARE
    record_id TEXT;
    embedding_function_url TEXT := 'https://<your-project-ref>.supabase.co/functions/v1/generate-embeddings';
BEGIN
    FOR record_id IN EXECUTE format(
        'SELECT id::text FROM %I WHERE description IS NOT NULL AND description_embedding IS NULL LIMIT %s',
        p_table,
        p_limit
    )
    LOOP
        RAISE LOG 'Generating embedding for %=%', p_entity_type, record_id;

        PERFORM net.http_post(
            url := embedding_function_url,
            body := jsonb_build_object(
                'entity_type', p_entity_type,
                'entity_id', record_id
            ),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer <YOUR_SERVICE_ROLE_KEY>'
            )
        );

        PERFORM pg_sleep(0.2);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Wrapper for tasks
CREATE OR REPLACE FUNCTION process_tasks_missing_embeddings()
RETURNS void AS $$
BEGIN
    PERFORM process_missing_embeddings('tasks', 'task');
END;
$$ LANGUAGE plpgsql;


-- Wrapper for tickets
CREATE OR REPLACE FUNCTION process_tickets_missing_embeddings()
RETURNS void AS $$
BEGIN
    PERFORM process_missing_embeddings('tickets', 'ticket');
END;
$$ LANGUAGE plpgsql;


-- Safely remove existing cron jobs if they exist
DO $$
BEGIN
    PERFORM cron.unschedule('process-task-embeddings');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

DO $$
BEGIN
    PERFORM cron.unschedule('process-ticket-embeddings');
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;


-- Schedule processors every 5 minutes
SELECT cron.schedule(
    'process-task-embeddings',
    '*/5 * * * *',
    $$SELECT process_tasks_missing_embeddings();$$
);

SELECT cron.schedule(
    'process-ticket-embeddings',
    '*/5 * * * *',
    $$SELECT process_tickets_missing_embeddings();$$
);