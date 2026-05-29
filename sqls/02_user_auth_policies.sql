-- First, drop all existing policies
DROP POLICY IF EXISTS "Team members can view their team" ON teams;
DROP POLICY IF EXISTS "Only admins can update their team" ON teams;
DROP POLICY IF EXISTS "Users can view members of their team" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Allow authenticated users to insert users" ON users;
DROP POLICY IF EXISTS "Allow authenticated users to insert teams" ON teams;

-- Temporarily disable RLS to make sure we can fix everything
ALTER TABLE teams DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Create a simple view to help with team membership checks
CREATE OR REPLACE VIEW user_teams AS
SELECT id, team_id FROM users;

-- Re-enable RLS
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create new policies for teams
CREATE POLICY "Team members can view their team" 
  ON teams FOR SELECT 
  USING (
    -- Only allow users to see the team they are actually assigned to
    id IN (
      SELECT team_id FROM users WHERE id = auth.uid()
    )
  );

CREATE POLICY "Only admins can update their team" 
  ON teams FOR UPDATE 
  USING (created_by = auth.uid());

CREATE POLICY "Allow team creation" 
  ON teams FOR INSERT 
  -- Restrict team creation to authenticated users
  WITH CHECK (auth.role() = 'authenticated');

-- Create new policies for users
CREATE POLICY "Users can view themselves" 
  ON users FOR SELECT 
  USING (id = auth.uid());

CREATE POLICY "Users can view team members" 
  ON users FOR SELECT 
  USING (
    -- Cross-reference with the user_teams view to restrict visibility
    team_id IN (
      SELECT team_id FROM user_teams WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own profile" 
  ON users FOR UPDATE 
  USING (id = auth.uid());

CREATE POLICY "Allow user creation" 
  ON users FOR INSERT 
  -- Users can only insert their own profile record during signup
  WITH CHECK (auth.uid() = id);

-- Grant and Revoke permissions (Security Hardening)
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT ON user_teams TO authenticated;

-- Revoke all access from anonymous (not logged in) users
REVOKE ALL ON teams FROM anon;
REVOKE ALL ON users FROM anon;

-- Grant standard access to authenticated users only
GRANT SELECT, INSERT, UPDATE ON teams TO authenticated;
GRANT SELECT, INSERT, UPDATE ON users TO authenticated;