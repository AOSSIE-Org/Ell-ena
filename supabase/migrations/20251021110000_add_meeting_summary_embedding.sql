-- Add missing summary_embedding column to meetings table for vector similarity search
-- This column is referenced by get_similar_meetings(), search_meeting_summaries_by_resp_id(),
-- process_meetings_missing_embeddings(), and the generate-embeddings Edge Function.

ALTER TABLE meetings
ADD COLUMN summary_embedding vector(768);