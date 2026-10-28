ALTER TABLE meetings
  ADD COLUMN IF NOT EXISTS transcription_status TEXT;
