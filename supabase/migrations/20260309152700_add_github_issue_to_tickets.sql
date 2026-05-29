-- Migration to add GitHub issue tracking to tickets
ALTER TABLE tickets
ADD COLUMN github_issue_number TEXT,
ADD COLUMN github_issue_url TEXT;
