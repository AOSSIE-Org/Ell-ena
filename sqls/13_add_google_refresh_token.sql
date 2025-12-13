-- Add google_refresh_token column to users table for Calendar API integration
ALTER TABLE users ADD COLUMN google_refresh_token TEXT;

-- Add comment to document the column purpose
COMMENT ON COLUMN users.google_refresh_token IS 'Stores Google OAuth refresh token for Calendar API access';
