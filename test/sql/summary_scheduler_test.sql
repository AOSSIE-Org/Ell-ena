\set ON_ERROR_STOP on

-- Upgrade the historical function, including deployment-specific settings.
BEGIN;
\ir summary_scheduler_setup.sql
\ir ../../supabase/migrations/20251021080000_meetings_ai_summary.sql
DO $$
BEGIN
    EXECUTE replace(replace(
        pg_get_functiondef('public.process_unsummarized_meetings()'::regprocedure),
        'https://project--ref.supabase.co', 'https://scheduler.example.invalid'),
        'Bearer SERVICE_ROLE_KEY', 'Bearer test-only-token');
END;
$$;
\ir ../../supabase/migrations/20261027120000_summary_scheduler_backlog.sql
\ir summary_scheduler_assertions.sql
-- Exercise the upgraded HTTP call, not just its source text.
UPDATE public.meetings SET meeting_summary_json = NULL
WHERE id = '00000000-0000-0000-0000-000000000001';
SELECT public.process_unsummarized_meetings();
SELECT public.assert_summary(
    (SELECT count(*) = 1 AND bool_and(
        url = 'https://scheduler.example.invalid/functions/v1/summarize-transcription'
        AND headers->>'Authorization' = 'Bearer test-only-token'
        AND headers->>'Content-Type' = 'application/json')
     FROM public.summary_requests),
    'the upgrade must preserve configured endpoint, authorization and content type'
);
SELECT public.assert_summary(
    (SELECT count(*) = 1 AND bool_and(name = 'process-summaries'
        AND schedule = '* * * * *'
        AND command = 'SELECT process_unsummarized_meetings();')
     FROM cron.scheduled_jobs),
    'the upgrade must retain the existing minute schedule without duplicating it'
);
ROLLBACK;

-- The documented SQL mirror must behave identically on a fresh installation.
BEGIN;
\ir summary_scheduler_setup.sql
\ir ../../sqls/08_meetings_ai_summary.sql
\ir summary_scheduler_assertions.sql
ROLLBACK;

SELECT 'Summary scheduler upgrade and SQL mirror regressions passed' AS result;
