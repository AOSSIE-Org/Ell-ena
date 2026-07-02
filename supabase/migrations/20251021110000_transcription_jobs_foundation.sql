-- Tracks audio upload paths and async job status per meeting.
-- Does not modify the existing Vexa pipeline on the meetings table.

CREATE TABLE transcription_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meeting_id UUID NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    audio_path TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_transcription_jobs_meeting_id ON transcription_jobs(meeting_id);
CREATE INDEX idx_transcription_jobs_status ON transcription_jobs(status);
CREATE INDEX idx_transcription_jobs_pending_created_at
    ON transcription_jobs(created_at)
    WHERE status = 'pending';

ALTER TABLE transcription_jobs ENABLE ROW LEVEL SECURITY;

-- Team members can view jobs for meetings in their team.
CREATE POLICY transcription_jobs_view_policy ON transcription_jobs
    FOR SELECT
    USING (
        meeting_id IN (
            SELECT id FROM meetings
            WHERE team_id IN (
                SELECT team_id FROM users WHERE id = auth.uid()
            )
        )
    );

-- Team members can enqueue jobs for meetings in their team.
CREATE POLICY transcription_jobs_insert_policy ON transcription_jobs
    FOR INSERT
    WITH CHECK (
        meeting_id IN (
            SELECT id FROM meetings
            WHERE team_id IN (
                SELECT team_id FROM users WHERE id = auth.uid()
            )
        )
    );

-- Meeting creators and team admins can update job rows.
-- Background workers use the service role and bypass RLS.
CREATE POLICY transcription_jobs_update_policy ON transcription_jobs
    FOR UPDATE
    USING (
        meeting_id IN (
            SELECT id FROM meetings m
            WHERE
                auth.uid() = m.created_by OR
                auth.uid() IN (
                    SELECT id FROM users
                    WHERE team_id = m.team_id AND role = 'admin'
                )
        )
    );

-- Meeting creators and team admins can delete jobs.
CREATE POLICY transcription_jobs_delete_policy ON transcription_jobs
    FOR DELETE
    USING (
        meeting_id IN (
            SELECT id FROM meetings m
            WHERE
                auth.uid() = m.created_by OR
                auth.uid() IN (
                    SELECT id FROM users
                    WHERE team_id = m.team_id AND role = 'admin'
                )
        )
    );

-- Private bucket for meeting audio uploads.
-- Object path convention: {team_id}/{meeting_id}/{filename}
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'meeting-recordings',
    'meeting-recordings',
    false,
    524288000,
    ARRAY[
        'audio/webm',
        'audio/wav',
        'audio/mpeg',
        'audio/mp4',
        'audio/ogg',
        'audio/x-m4a'
    ]
);

CREATE POLICY meeting_recordings_select_policy ON storage.objects
    FOR SELECT
    TO authenticated
    USING (
        bucket_id = 'meeting-recordings' AND
        (storage.foldername(name))[1] IN (
            SELECT team_id::text FROM users WHERE id = auth.uid()
        )
    );

CREATE POLICY meeting_recordings_insert_policy ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'meeting-recordings' AND
        (storage.foldername(name))[1] IN (
            SELECT team_id::text FROM users WHERE id = auth.uid()
        ) AND
        (storage.foldername(name))[2] IN (
            SELECT id::text FROM meetings
            WHERE team_id IN (
                SELECT team_id FROM users WHERE id = auth.uid()
            )
        )
    );

CREATE POLICY meeting_recordings_update_policy ON storage.objects
    FOR UPDATE
    TO authenticated
    USING (
        bucket_id = 'meeting-recordings' AND
        (storage.foldername(name))[2] IN (
            SELECT m.id::text FROM meetings m
            WHERE
                auth.uid() = m.created_by OR
                auth.uid() IN (
                    SELECT id FROM users
                    WHERE team_id = m.team_id AND role = 'admin'
                )
        )
    );

CREATE POLICY meeting_recordings_delete_policy ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'meeting-recordings' AND
        (storage.foldername(name))[2] IN (
            SELECT m.id::text FROM meetings m
            WHERE
                auth.uid() = m.created_by OR
                auth.uid() IN (
                    SELECT id FROM users
                    WHERE team_id = m.team_id AND role = 'admin'
                )
        )
    );
