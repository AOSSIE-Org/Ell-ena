-- Enable required extensions if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Function to start bots
CREATE OR REPLACE FUNCTION start_meeting_bot()
RETURNS void AS $$
DECLARE
  meeting_record RECORD;
BEGIN
  FOR meeting_record IN
    SELECT id, meeting_url
    FROM meetings
    WHERE 
      meeting_url LIKE '%meet.google.com%' AND
      meeting_date <= NOW() + INTERVAL '5 minutes' AND
      meeting_date > NOW() - INTERVAL '5 minutes' AND
      bot_started_at IS NULL
  LOOP
    PERFORM net.http_post(
      url:='https://' || current_setting('request.headers')::json->>'host' || '/functions/v1/start-bot',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('supabase.anon_key') || '"}'::jsonb,
      body:=jsonb_build_object(
        'meeting_url', meeting_record.meeting_url,
        'meeting_id', meeting_record.id
      )
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to fetch transcripts
CREATE OR REPLACE FUNCTION fetch_meeting_transcript()
RETURNS void AS $$
DECLARE
  meeting_record RECORD;
BEGIN
  FOR meeting_record IN
    SELECT id, meeting_url
    FROM meetings
    WHERE 
      meeting_url LIKE '%meet.google.com%' AND
      meeting_date + ((COALESCE(duration_minutes, 60)) * INTERVAL '1 minute') <= NOW() AND
      bot_started_at IS NOT NULL AND
      transcription_attempted_at IS NULL
  LOOP
    PERFORM net.http_post(
      url:='https://' || current_setting('request.headers')::json->>'host' || '/functions/v1/fetch-transcript',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer ' || current_setting('supabase.anon_key') || '"}'::jsonb,
      body:=jsonb_build_object(
        'meeting_url', meeting_record.meeting_url,
        'meeting_id', meeting_record.id
      )
    );
  END LOOP;
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
  PERFORM cron.unschedule('start-bot');
  PERFORM cron.schedule('start-bot', '* * * * *', 'SELECT start_meeting_bot()');

  PERFORM cron.unschedule('fetch-transcript');
  PERFORM cron.schedule('fetch-transcript', '* * * * *', 'SELECT fetch_meeting_transcript()');
END $$;
