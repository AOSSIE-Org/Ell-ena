-- backfill: embeddings for existing tasks/tickets (idempotent).
-- Prerequisites: migrations 20260717120000 + 20260717120100 applied,
-- generate-embeddings deployed, and worker URL/auth placeholders replaced
-- the same way as process_meetings_missing_embeddings.

SELECT process_tasks_missing_embeddings();
SELECT process_tickets_missing_embeddings();
