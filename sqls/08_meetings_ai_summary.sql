ALTER TABLE meetings
ADD COLUMN meeting_summary_json JSONB;

CREATE OR REPLACE FUNCTION process_unsummarized_meetings()
RETURNS void AS $$
DECLARE
    meeting_record RECORD;
    function_url TEXT := 'https://project--ref.supabase.co/functions/v1/summarize-transcription';
    resp jsonb;
BEGIN
    FOR meeting_record IN
        SELECT id, final_transcription
        FROM meetings
        WHERE final_transcription IS NOT NULL
          AND meeting_summary_json IS NULL
        -- Booking age does not indicate when the transcript became available.
        ORDER BY created_at, id
        LIMIT 50
    LOOP
        RAISE LOG 'Processing meeting_id=%', meeting_record.id;

        resp := net.http_post(
            url := function_url,
            body := jsonb_build_object('meeting_id', meeting_record.id),
            headers := '{
                "Content-Type": "application/json",
                "Authorization": "Bearer SERVICE_ROLE_KEY"
            }'::jsonb
        );

        RAISE LOG 'Edge Function response for meeting_id=% : %', meeting_record.id, resp;

        -- small delay so you don’t overwhelm your Edge Function
        PERFORM pg_sleep(0.2);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- 2. Schedule it to run every minute
SELECT cron.schedule(
    'process-summaries',
    '* * * * *',
    $$SELECT process_unsummarized_meetings();$$
);
