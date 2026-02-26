-- Meetings table
CREATE TABLE meetings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_number TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    meeting_date TIMESTAMP WITH TIME ZONE NOT NULL,
    meeting_url TEXT,
    transcription TEXT DEFAULT NULL,
    ai_summary TEXT DEFAULT NULL,
    created_by UUID REFERENCES auth.users(id),
    team_id UUID REFERENCES teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

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


CREATE OR REPLACE FUNCTION delete_old_meetings()
RETURNS void AS $$
BEGIN
    DELETE FROM meetings
    WHERE meeting_date < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

CREATE EXTENSION IF NOT EXISTS pg_cron;
DO $$ BEGIN
    SELECT cron.unschedule('delete_old_meetings');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;
SELECT cron.schedule('30 2 * * *', 'SELECT delete_old_meetings();');