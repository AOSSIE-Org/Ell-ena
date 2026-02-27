CREATE OR REPLACE FUNCTION process_missing_embeddings(
    p_table TEXT,
    p_entity_type TEXT,
    p_limit INT DEFAULT 50
)
RETURNS void AS $$
DECLARE
    record_id TEXT;
    req_id BIGINT;

    -- ⚠ Replace PROJECT_REF in production
    embedding_function_url TEXT :=
        'https://PROJECT_REF.supabase.co/functions/v1/generate-embeddings';
BEGIN
    -- Enforce supported tables only (prevents misuse)
    IF p_table NOT IN ('tasks', 'tickets') THEN
        RAISE EXCEPTION 'Unsupported table: %', p_table;
    END IF;

    IF p_entity_type NOT IN ('task', 'ticket') THEN
        RAISE EXCEPTION 'Unsupported entity_type: %', p_entity_type;
    END IF;

    -- Fail fast if placeholder not replaced
    IF embedding_function_url LIKE '%PROJECT_REF%' THEN
        RAISE EXCEPTION 'embedding_function_url placeholder not replaced';
    END IF;

    -- Defensive limit clamp
    p_limit := greatest(1, least(p_limit, 500));

    FOR record_id IN EXECUTE format(
        'SELECT id::text FROM %I
         WHERE description IS NOT NULL
           AND description_embedding IS NULL
         LIMIT %s',
        p_table,
        p_limit
    )
    LOOP
        SELECT net.http_post(
            url := embedding_function_url,
            body := jsonb_build_object(
                'entity_type', p_entity_type,
                'entity_id', record_id
            ),
            headers := jsonb_build_object(
                'Content-Type', 'application/json'
                -- Maintainers must add Authorization header if verify_jwt = true
            )
        )
        INTO req_id;

        RAISE LOG 'Queued embedding request id=% for %=%',
            req_id, p_entity_type, record_id;

        PERFORM pg_sleep(0.2);
    END LOOP;
END;
$$ LANGUAGE plpgsql;