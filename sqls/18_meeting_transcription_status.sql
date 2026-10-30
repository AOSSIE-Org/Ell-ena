-- Mirrors supabase/migrations/20260926190000_meeting_transcription_status.sql
ALTER TABLE meetings
  ADD COLUMN IF NOT EXISTS transcription_status TEXT;
