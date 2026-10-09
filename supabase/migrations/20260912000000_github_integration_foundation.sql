-- GitHub integration foundation: ticket sync fields, task PR fields, webhook delivery idempotency.
--
-- sync_to_github = user intent (stays true after a successful sync).
-- github_sync_status = operational state of the sync pipeline.
-- gh_issue_id = GitHub per-repository issue number (idempotency guard once set).

-- ---------------------------------------------------------------------------
-- tickets
-- ---------------------------------------------------------------------------
ALTER TABLE tickets
  ADD COLUMN IF NOT EXISTS sync_to_github BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS github_sync_status TEXT NOT NULL DEFAULT 'not_requested',
  ADD COLUMN IF NOT EXISTS github_sync_error TEXT,
  ADD COLUMN IF NOT EXISTS gh_issue_id BIGINT,
  ADD COLUMN IF NOT EXISTS gh_issue_url TEXT,
  ADD COLUMN IF NOT EXISTS gh_repo TEXT;

ALTER TABLE tickets
  DROP CONSTRAINT IF EXISTS tickets_github_sync_status_check;

ALTER TABLE tickets
  ADD CONSTRAINT tickets_github_sync_status_check
  CHECK (
    github_sync_status IN (
      'not_requested',
      'pending',
      'synced',
      'failed'
    )
  );

-- Tickets awaiting sync: intent on, no linked issue yet.
CREATE INDEX IF NOT EXISTS idx_tickets_github_sync_pending
  ON tickets (github_sync_status)
  WHERE sync_to_github = true
    AND gh_issue_id IS NULL;

COMMENT ON COLUMN tickets.sync_to_github IS
  'User intent: when true, this ticket should be synchronized with GitHub. Remains true after a successful sync.';

COMMENT ON COLUMN tickets.github_sync_status IS
  'Operational sync state: not_requested | pending | synced | failed.';

COMMENT ON COLUMN tickets.github_sync_error IS
  'Latest sync failure detail; NULL when there is no current error.';

COMMENT ON COLUMN tickets.gh_issue_id IS
  'GitHub issue number within gh_repo. Once set, used as an idempotency guard against creating another issue for this ticket.';

COMMENT ON COLUMN tickets.gh_issue_url IS
  'Public HTML URL of the linked GitHub issue.';

COMMENT ON COLUMN tickets.gh_repo IS
  'GitHub repository in owner/name form associated with gh_issue_id.';

-- ---------------------------------------------------------------------------
-- tasks
-- ---------------------------------------------------------------------------
ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS gh_pr_url TEXT,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

COMMENT ON COLUMN tasks.gh_pr_url IS
  'URL of the GitHub pull request that completed this task (set when a linked PR merges).';

COMMENT ON COLUMN tasks.completed_at IS
  'Timestamp when the task was completed via GitHub PR merge (or other completion flows).';

-- ---------------------------------------------------------------------------
-- webhook_events (delivery idempotency foundation only)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT webhook_events_delivery_id_key UNIQUE (delivery_id)
);

COMMENT ON TABLE webhook_events IS
  'Stores GitHub webhook delivery IDs so the same delivery is not processed twice.';

COMMENT ON COLUMN webhook_events.delivery_id IS
  'Value of the X-GitHub-Delivery header for a webhook request.';

ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;

-- No authenticated-client policies: only the service role (bypasses RLS) writes/reads this table.
