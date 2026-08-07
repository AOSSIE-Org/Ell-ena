-- NULL-sentinel + pg_cron for task/ticket embeddings
-- (same architecture as process_meetings_missing_embeddings).

CREATE OR REPLACE FUNCTION reset_task_description_embedding()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.description IS DISTINCT FROM NEW.description
     OR OLD.title IS DISTINCT FROM NEW.title THEN
    NEW.description_embedding := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_reset_task_description_embedding ON tasks;
CREATE TRIGGER trg_reset_task_description_embedding
BEFORE UPDATE OF title, description ON tasks
FOR EACH ROW
EXECUTE FUNCTION reset_task_description_embedding();

CREATE OR REPLACE FUNCTION reset_ticket_description_embedding()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.description IS DISTINCT FROM NEW.description
     OR OLD.title IS DISTINCT FROM NEW.title THEN
    NEW.description_embedding := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_reset_ticket_description_embedding ON tickets;
CREATE TRIGGER trg_reset_ticket_description_embedding
BEFORE UPDATE OF title, description ON tickets
FOR EACH ROW
EXECUTE FUNCTION reset_ticket_description_embedding();

CREATE OR REPLACE FUNCTION process_tasks_missing_embeddings()
RETURNS void AS $$
DECLARE
    task_record RECORD;
    embedding_function_url TEXT := 'https://project--ref.supabase.co/functions/v1/generate-embeddings';
    resp jsonb;
BEGIN
    FOR task_record IN
        SELECT id
        FROM tasks
        WHERE description_embedding IS NULL
          AND (
            (title IS NOT NULL AND btrim(title) <> '')
            OR (description IS NOT NULL AND btrim(description) <> '')
          )
    LOOP
        RAISE LOG 'Generating embedding for task_id=%', task_record.id;

        resp := net.http_post(
            url := embedding_function_url,
            body := jsonb_build_object(
                'entity_type', 'task',
                'id', task_record.id
            ),
            headers := '{
                "Content-Type": "application/json",
                "Authorization": "Bearer SERVICE_ROLE_KEY"
            }'::jsonb
        );

        RAISE LOG 'Embedding Function response for task_id=% : %', task_record.id, resp;
        PERFORM pg_sleep(0.2);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION process_tickets_missing_embeddings()
RETURNS void AS $$
DECLARE
    ticket_record RECORD;
    embedding_function_url TEXT := 'https://project--ref.supabase.co/functions/v1/generate-embeddings';
    resp jsonb;
BEGIN
    FOR ticket_record IN
        SELECT id
        FROM tickets
        WHERE description_embedding IS NULL
          AND (
            (title IS NOT NULL AND btrim(title) <> '')
            OR (description IS NOT NULL AND btrim(description) <> '')
          )
    LOOP
        RAISE LOG 'Generating embedding for ticket_id=%', ticket_record.id;

        resp := net.http_post(
            url := embedding_function_url,
            body := jsonb_build_object(
                'entity_type', 'ticket',
                'id', ticket_record.id
            ),
            headers := '{
                "Content-Type": "application/json",
                "Authorization": "Bearer SERVICE_ROLE_KEY"
            }'::jsonb
        );

        RAISE LOG 'Embedding Function response for ticket_id=% : %', ticket_record.id, resp;
        PERFORM pg_sleep(0.2);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT cron.schedule(
    'process-missing-task-embeddings',
    '* * * * *',
    $$SELECT process_tasks_missing_embeddings();$$
);

SELECT cron.schedule(
    'process-missing-ticket-embeddings',
    '* * * * *',
    $$SELECT process_tickets_missing_embeddings();$$
);

-- You can also run it manually once to process existing tasks/tickets:
-- SELECT process_tasks_missing_embeddings();
-- SELECT process_tickets_missing_embeddings();
