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
    transcription_error TEXT DEFAULT NULL,

    created_by UUID REFERENCES auth.users(id),
    team_id UUID REFERENCES teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON COLUMN meetings.transcription_error IS 'Stores error messages when transcription processing fails';

-- Generate meeting number trigger
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

DROP TRIGGER IF EXISTS set_meeting_number ON meetings;
CREATE TRIGGER set_meeting_number
BEFORE INSERT ON meetings
FOR EACH ROW
EXECUTE FUNCTION generate_meeting_number();

-- Enable Row Level Security
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;

-- MEETINGS POLICIES (SECURE)

-- View policy - all team members can view meetings
DROP POLICY IF EXISTS meetings_view_policy ON meetings;
CREATE POLICY meetings_view_policy ON meetings
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = meetings.team_id
        )
    );

-- Insert policy - any authenticated user can create a meeting for their team
-- Enforce created_by = auth.uid()
DROP POLICY IF EXISTS meetings_insert_policy ON meetings;
CREATE POLICY meetings_insert_policy ON meetings
    FOR INSERT
    WITH CHECK (
        auth.uid() = created_by
        AND EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = meetings.team_id
        )
    );

-- Delete policy - only admins or the creator (who is still on the team) can delete meetings
DROP POLICY IF EXISTS meetings_delete_policy ON meetings;
CREATE POLICY meetings_delete_policy ON meetings
    FOR DELETE
    USING (
        -- Creator can delete only if they are still on the team
        (
            auth.uid() = created_by
            AND EXISTS (
                SELECT 1 FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = meetings.team_id
            )
        )
        OR EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = meetings.team_id
              AND users.role = 'admin'
        )
    );

-- Update policy - creator (who is still on the team) OR admin can update meetings
DROP POLICY IF EXISTS meetings_update_policy ON meetings;
CREATE POLICY meetings_update_policy ON meetings
    FOR UPDATE
    USING (
        -- Creator can update only if they are still on the team
        (
            auth.uid() = created_by
            AND EXISTS (
                SELECT 1 FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = meetings.team_id
            )
        )
        OR EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = meetings.team_id
              AND users.role = 'admin'
        )
    )
    WITH CHECK (
        -- Same conditions apply to the new row
        (
            auth.uid() = created_by
            AND EXISTS (
                SELECT 1 FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = meetings.team_id
            )
        )
        OR EXISTS (
            SELECT 1 FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = meetings.team_id
              AND users.role = 'admin'
        )
    );

-- Guard sensitive fields (column-level) at the database level
-- Non-admins (including creator) can NOT modify transcription/AI/bot fields.
-- Admins can modify everything.
-- Also prevent non-admins from changing team_id

CREATE OR REPLACE FUNCTION guard_meeting_sensitive_fields()
RETURNS TRIGGER AS $$
DECLARE
  is_admin BOOLEAN;
BEGIN
  -- Check if the current user is an admin of the ORIGINAL team
  SELECT EXISTS (
    SELECT 1
    FROM users
    WHERE users.id = auth.uid()
      AND users.team_id = OLD.team_id
      AND users.role = 'admin'
  )
  INTO is_admin;

  IF NOT is_admin THEN
    -- Non-admins cannot modify sensitive fields
    IF NEW.transcription IS DISTINCT FROM OLD.transcription
       OR NEW.ai_summary IS DISTINCT FROM OLD.ai_summary
       OR NEW.duration_minutes IS DISTINCT FROM OLD.duration_minutes
       OR NEW.bot_started_at IS DISTINCT FROM OLD.bot_started_at
       OR NEW.transcription_attempted_at IS DISTINCT FROM OLD.transcription_attempted_at
       OR NEW.transcription_error IS DISTINCT FROM OLD.transcription_error
    THEN
      RAISE EXCEPTION 'permission denied: only admins can modify transcription/AI/bot fields';
    END IF;
    
    -- Non-admins cannot change team_id
    IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
      RAISE EXCEPTION 'permission denied: only admins can change team_id';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS guard_meeting_sensitive_fields ON meetings;
CREATE TRIGGER guard_meeting_sensitive_fields
BEFORE UPDATE ON meetings
FOR EACH ROW
EXECUTE FUNCTION guard_meeting_sensitive_fields();

-- Update the updated_at timestamp automatically
-- NOTE: update_updated_at_column() is defined in sqls/04_tickets_schema.sql
DROP TRIGGER IF EXISTS update_meetings_updated_at ON meetings;
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
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'delete-old-meetings') THEN
    PERFORM cron.unschedule('delete-old-meetings');
  END IF;
  PERFORM cron.schedule('delete-old-meetings', '30 2 * * *', 'SELECT delete_old_meetings()');
END $$;