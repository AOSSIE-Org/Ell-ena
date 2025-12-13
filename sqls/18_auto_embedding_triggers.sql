-- Database triggers for automatic embedding generation
-- Automatically generates embeddings when tasks/tickets are created or updated

-- Trigger function to generate task embeddings via Edge Function
CREATE OR REPLACE FUNCTION trigger_task_embedding_generation()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger if title or description changed, or if embedding is missing
    IF (TG_OP = 'INSERT' OR 
        NEW.title IS DISTINCT FROM OLD.title OR 
        NEW.description IS DISTINCT FROM OLD.description OR
        NEW.description_embedding IS NULL) THEN
        
        -- Queue embedding generation asynchronously via Edge Function
        PERFORM net.http_post(
            url := current_setting('app.settings.supabase_url') || '/functions/v1/generate-task-embeddings',
            body := jsonb_build_object('task_id', NEW.id),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key')
            )
        );
        
        RAISE LOG 'Queued embedding generation for task: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to generate ticket embeddings via Edge Function
CREATE OR REPLACE FUNCTION trigger_ticket_embedding_generation()
RETURNS TRIGGER AS $$
BEGIN
    -- Only trigger if title, description, category or priority changed, or if embedding is missing
    IF (TG_OP = 'INSERT' OR 
        NEW.title IS DISTINCT FROM OLD.title OR 
        NEW.description IS DISTINCT FROM OLD.description OR
        NEW.category IS DISTINCT FROM OLD.category OR
        NEW.priority IS DISTINCT FROM OLD.priority OR
        NEW.description_embedding IS NULL) THEN
        
        -- Queue embedding generation asynchronously via Edge Function
        PERFORM net.http_post(
            url := current_setting('app.settings.supabase_url') || '/functions/v1/generate-ticket-embeddings',
            body := jsonb_build_object('ticket_id', NEW.id),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key')
            )
        );
        
        RAISE LOG 'Queued embedding generation for ticket: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers (DROP IF EXISTS to allow idempotent migrations)
DROP TRIGGER IF EXISTS task_embedding_trigger ON tasks;
CREATE TRIGGER task_embedding_trigger
    AFTER INSERT OR UPDATE ON tasks
    FOR EACH ROW
    EXECUTE FUNCTION trigger_task_embedding_generation();

DROP TRIGGER IF EXISTS ticket_embedding_trigger ON tickets;
CREATE TRIGGER ticket_embedding_trigger
    AFTER INSERT OR UPDATE ON tickets
    FOR EACH ROW
    EXECUTE FUNCTION trigger_ticket_embedding_generation();

COMMENT ON TRIGGER task_embedding_trigger ON tasks IS 
'Automatically generates vector embeddings for task descriptions when tasks are created or updated';

COMMENT ON TRIGGER ticket_embedding_trigger ON tickets IS 
'Automatically generates vector embeddings for ticket descriptions when tickets are created or updated';

-- Note: Requires Supabase configuration settings:
-- ALTER DATABASE postgres SET app.settings.supabase_url = 'https://your-project.supabase.co';
-- ALTER DATABASE postgres SET app.settings.supabase_service_role_key = 'your-service-role-key';
