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
    id IN (
      SELECT team_id FROM users WHERE id = auth.uid()
    )
  );

CREATE POLICY "Only admins can update their team" 
  ON teams FOR UPDATE 
  USING (created_by = auth.uid());

CREATE POLICY "Allow team creation" 
  ON teams FOR INSERT 
  WITH CHECK (TRUE);

-- Create new policies for users
CREATE POLICY "Users can view themselves" 
  ON users FOR SELECT 
  USING (id = auth.uid());

CREATE POLICY "Users can view team members" 
  ON users FOR SELECT 
  USING (
    team_id IN (
      SELECT team_id FROM user_teams WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own profile" 
  ON users FOR UPDATE 
  USING (id = auth.uid());

CREATE POLICY "Allow user creation" 
  ON users FOR INSERT 
  WITH CHECK (TRUE);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON user_teams TO anon, authenticated;
GRANT ALL ON teams TO anon, authenticated;
GRANT ALL ON users TO anon, authenticated; 