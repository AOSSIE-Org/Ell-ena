-- Enable required extensions for bot functionality
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Meetings table with all required columns for transcription
CREATE TABLE meetings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_number TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    meeting_date TIMESTAMP WITH TIME ZONE NOT NULL,
    meeting_url TEXT,
    transcription TEXT DEFAULT NULL,
    ai_summary TEXT DEFAULT NULL,
    
    -- New columns for transcription bot functionality
    duration_minutes INT DEFAULT 60,
    bot_started_at TIMESTAMP WITH TIME ZONE,
    transcription_attempted_at TIMESTAMP WITH TIME ZONE,
    transcription_error TEXT DEFAULT NULL,  -- Stores error messages when transcription processing fails
    
    created_by UUID REFERENCES auth.users(id),
    team_id UUID REFERENCES teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON COLUMN meetings.transcription_error IS 'Stores error messages when transcription processing fails';

CREATE OR REPLACE FUNCTION generate_meeting_number()
RETURNS TRIGGER AS $$
DECLARE
    next_number INT;
    generated_meeting_number TEXT;
BEGIN
    -- Get the next number for the 'MTG' prefix
    SELECT COALESCE(MAX(SUBSTRING(meetings.meeting_number FROM '[0-9]+')::INT), 0) + 1
    INTO next_number
    FROM meetings
    WHERE meetings.meeting_number LIKE 'MTG-%';

    -- Format the meeting number (e.g., MTG-001)
    generated_meeting_number := 'MTG-' || LPAD(next_number::TEXT, 3, '0');

    -- Set the meeting number
    NEW.meeting_number := generated_meeting_number;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_meeting_number
BEFORE INSERT ON meetings
FOR EACH ROW
EXECUTE FUNCTION generate_meeting_number();

-- Enable Row Level Security
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;

-- View policy - all team members can view meetings
CREATE POLICY meetings_view_policy ON meetings
    FOR SELECT
    USING (
        team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    );

-- Insert policy - any authenticated user can create a meeting for their team
CREATE POLICY meetings_insert_policy ON meetings
    FOR INSERT
    WITH CHECK (
        auth.uid() = created_by AND
        team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    );

-- Delete policy - only admins or the creator can delete meetings
CREATE POLICY meetings_delete_policy ON meetings
    FOR DELETE
    USING (
        auth.uid() = created_by OR
        auth.uid() IN (
            SELECT id FROM users 
            WHERE team_id = meetings.team_id AND role = 'admin'
        )
    );

-- Update policy - only the creator or admins can update meetings
CREATE POLICY meetings_update_policy ON meetings
    FOR UPDATE
    USING (
        auth.uid() = created_by OR
        auth.uid() IN (
            SELECT id FROM users 
            WHERE team_id = meetings.team_id AND role = 'admin'
        )
    );

-- Update the updated_at timestamp automatically
CREATE TRIGGER update_meetings_updated_at
BEFORE UPDATE ON meetings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

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

-- Scheduled jobs for bot automation
-- Note: IF EXISTS checks allow safe re-running during development/debugging
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'start-bot') THEN
    PERFORM cron.unschedule('start-bot');
  END IF;
  PERFORM cron.schedule('start-bot', '* * * * *', 'SELECT start_meeting_bot()');
  
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'fetch-transcript') THEN
    PERFORM cron.unschedule('fetch-transcript');
  END IF;
  PERFORM cron.schedule('fetch-transcript', '* * * * *', 'SELECT fetch_meeting_transcript()');
END $$;

-- Function to delete old meetings
CREATE OR REPLACE FUNCTION delete_old_meetings()
RETURNS void AS $$
BEGIN
    DELETE FROM meetings
    WHERE meeting_date < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Cleanup cron job
-- Note: IF EXISTS check allows safe re-running during development/debugging
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'delete-old-meetings') THEN
    PERFORM cron.unschedule('delete-old-meetings');
  END IF;
  PERFORM cron.schedule('delete-old-meetings', '30 2 * * *', 'SELECT delete_old_meetings()');
END $$;