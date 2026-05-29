-- Migration to add GitHub issue tracking to tickets
ALTER TABLE tickets
ADD COLUMN github_issue_number TEXT,
ADD COLUMN github_issue_url TEXT;

-- Create index for fast webhook lookups without locking the table
CREATE INDEX IF NOT EXISTS idx_tickets_github_issue_number ON tickets (github_issue_number);
