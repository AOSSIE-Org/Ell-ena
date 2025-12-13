-- ============================================================
-- Enable required extensions
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- ============================================================
-- Meetings table
-- ============================================================
CREATE TABLE IF NOT EXISTS meetings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Human-readable meeting identifier
    meeting_number TEXT UNIQUE,

    title TEXT NOT NULL,
    description TEXT,

    meeting_date TIMESTAMP WITH TIME ZONE NOT NULL,
    meeting_url TEXT,

    -- Transcription related fields
    transcription TEXT,
    ai_summary TEXT,

    duration_minutes INT NOT NULL DEFAULT 60,
    bot_started_at TIMESTAMP WITH TIME ZONE,
    transcription_attempted_at TIMESTAMP WITH TIME ZONE,
    transcription_error TEXT,

    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

COMMENT ON COLUMN meetings.transcription_error
IS 'Stores error messages when transcription processing fails';

-- ============================================================
-- Auto-generate meeting number (MTG-001 format)
-- ============================================================
CREATE OR REPLACE FUNCTION generate_meeting_number()
RETURNS TRIGGER AS $$
DECLARE
    next_number INT;
BEGIN
    SELECT COALESCE(
        MAX(SUBSTRING(meeting_number FROM '[0-9]+')::INT), 0
    ) + 1
    INTO next_number
    FROM meetings
    WHERE meeting_number LIKE 'MTG-%';

    NEW.meeting_number := 'MTG-' || LPAD(next_number::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_meeting_number
BEFORE INSERT ON meetings
FOR EACH ROW
WHEN (NEW.meeting_number IS NULL)
EXECUTE FUNCTION generate_meeting_number();

-- ============================================================
-- Automatically update updated_at
-- ============================================================
CREATE TRIGGER trg_update_meetings_updated_at
BEFORE UPDATE ON meetings
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- Row Level Security
-- ============================================================
ALTER TABLE meetings ENABLE ROW LEVEL SECURITY;

-- View policy
CREATE POLICY meetings_select
ON meetings
FOR SELECT
USING (
    team_id IN (
        SELECT team_id FROM users WHERE id = auth.uid()
    )
);

-- Insert policy
CREATE POLICY meetings_insert
ON meetings
FOR INSERT
WITH CHECK (
    auth.uid() = created_by
    AND team_id IN (
        SELECT team_id FROM users WHERE id = auth.uid()
    )
);

-- Update policy
CREATE POLICY meetings_update
ON meetings
FOR UPDATE
USING (
    auth.uid() = created_by
    OR auth.uid() IN (
        SELECT id FROM users
        WHERE team_id = meetings.team_id
        AND role = 'admin'
    )
);

-- Delete policy
CREATE POLICY meetings_delete
ON meetings
FOR DELETE
USING (
    auth.uid() = created_by
    OR auth.uid() IN (
        SELECT id FROM users
        WHERE team_id = meetings.team_id
        AND role = 'admin'
    )
);

-- ============================================================
-- Start meeting bot
-- ============================================================
CREATE OR REPLACE FUNCTION start_meeting_bot()
RETURNS void AS $$
DECLARE
    m RECORD;
BEGIN
    FOR m IN
        SELECT id, meeting_url
        FROM meetings
        WHERE meeting_url LIKE '%meet.google.com%'
          AND meeting_date BETWEEN NOW() - INTERVAL '5 minutes'
                               AND NOW() + INTERVAL '5 minutes'
          AND bot_started_at IS NULL
    LOOP
        PERFORM net.http_post(
            url := format(
                'https://%s/functions/v1/start-bot',
                current_setting('request.headers')::json->>'host'
            ),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('supabase.anon_key')
            ),
            body := jsonb_build_object(
                'meeting_id', m.id,
                'meeting_url', m.meeting_url
            )
        );

        UPDATE meetings
        SET bot_started_at = NOW()
        WHERE id = m.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Fetch meeting transcript
-- ============================================================
CREATE OR REPLACE FUNCTION fetch_meeting_transcript()
RETURNS void AS $$
DECLARE
    m RECORD;
BEGIN
    FOR m IN
        SELECT id, meeting_url, duration_minutes
        FROM meetings
        WHERE meeting_url LIKE '%meet.google.com%'
          AND bot_started_at IS NOT NULL
          AND transcription_attempted_at IS NULL
          AND meeting_date
              + (COALESCE(duration_minutes, 60) * INTERVAL '1 minute')
              <= NOW()
    LOOP
        PERFORM net.http_post(
            url := format(
                'https://%s/functions/v1/fetch-transcript',
                current_setting('request.headers')::json->>'host'
            ),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('supabase.anon_key')
            ),
            body := jsonb_build_object(
                'meeting_id', m.id,
                'meeting_url', m.meeting_url
            )
        );

        UPDATE meetings
        SET transcription_attempted_at = NOW()
        WHERE id = m.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Cron jobs
-- ============================================================
DO $$
BEGIN
    PERFORM cron.unschedule('start-bot') 
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'start-bot');

    PERFORM cron.schedule(
        'start-bot',
        '* * * * *',
        'SELECT start_meeting_bot()'
    );

    PERFORM cron.unschedule('fetch-transcript')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'fetch-transcript');

    PERFORM cron.schedule(
        'fetch-transcript',
        '* * * * *',
        'SELECT fetch_meeting_transcript()'
    );
END $$;

-- ============================================================
-- Cleanup old meetings
-- ============================================================
CREATE OR REPLACE FUNCTION delete_old_meetings()
RETURNS void AS $$
BEGIN
    DELETE FROM meetings
    WHERE meeting_date < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

DO $$
BEGIN
    PERFORM cron.unschedule('delete-old-meetings')
    WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'delete-old-meetings');

    PERFORM cron.schedule(
        'delete-old-meetings',
        '30 2 * * *',
        'SELECT delete_old_meetings()'
    );
END $$;
