-- The endpoint and authorization in this function are configured per deployment.
-- Replace only the eligibility cutoff, preserving that configuration and the
-- existing cron job. Do not replay the original migration's placeholders.
DO $$
DECLARE
    function_definition TEXT;
    age_filter CONSTANT TEXT := 'AND created_at > NOW() - INTERVAL ''1 day''';
BEGIN
    SELECT pg_get_functiondef('public.process_unsummarized_meetings()'::regprocedure)
    INTO function_definition;

    IF position(age_filter IN function_definition) = 0 THEN
        RAISE EXCEPTION 'Unexpected summary scheduler definition: review the age filter before applying this migration';
    END IF;

    -- Keep old pending meetings eligible, with a deterministic, bounded batch.
    EXECUTE replace(function_definition, age_filter,
        'ORDER BY created_at, id LIMIT 50');
END;
$$;
