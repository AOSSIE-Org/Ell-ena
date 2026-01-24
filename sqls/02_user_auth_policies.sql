-- Drop helper functions
DROP FUNCTION IF EXISTS is_admin_in_same_team(UUID);
DROP FUNCTION IF EXISTS get_current_user_role();

-- Drop policies on teams table (organized by operation: SELECT, INSERT, UPDATE)
DROP POLICY IF EXISTS "Team members can view their team" ON teams;
DROP POLICY IF EXISTS "Allow team creation" ON teams;
DROP POLICY IF EXISTS "Allow authenticated users to insert teams" ON teams;
DROP POLICY IF EXISTS "Only admins can update their team" ON teams;

-- Drop policies on users table (organized by operation: SELECT, INSERT, UPDATE)
DROP POLICY IF EXISTS "Users can view themselves" ON users;
DROP POLICY IF EXISTS "Users can view team members" ON users;
DROP POLICY IF EXISTS "Users can view members of their team" ON users;  -- Legacy policy
DROP POLICY IF EXISTS "Allow user creation" ON users;
DROP POLICY IF EXISTS "Allow authenticated users to insert users" ON users;  -- Legacy policy
DROP POLICY IF EXISTS "Users can update their own profile" ON users;  -- Legacy policy
DROP POLICY IF EXISTS "Users can update their own profile (except role)" ON users;
DROP POLICY IF EXISTS "Admins can manage roles within their team" ON users;

-- Temporarily disable RLS to make sure we can fix everything
ALTER TABLE teams DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;

-- Create a simple view to help with team membership checks
CREATE OR REPLACE VIEW user_teams AS
SELECT id, team_id FROM users;

-- Helper function to check if current user is admin in same team (bypasses RLS)
CREATE OR REPLACE FUNCTION is_admin_in_same_team(target_team_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM users
    WHERE id = auth.uid()
      AND role = 'admin'
      AND team_id = target_team_id
      AND team_id IS NOT NULL
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Helper function to get current user's role (bypasses RLS)
CREATE OR REPLACE FUNCTION get_current_user_role()
RETURNS TEXT AS $$
BEGIN
  RETURN (SELECT role FROM users WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Re-enable RLS
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create new policies for teams
CREATE POLICY "Team members can view their team" 
  ON teams FOR SELECT 
  USING (
    -- Everyone can see all teams for now (we'll restrict this later if needed)
    TRUE
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

CREATE POLICY "Users can update their own profile (except role)"
  ON users
  FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    -- Prevent users from changing their own role
    AND role = get_current_user_role()
  );

-- Policy for admins to update roles of team members
-- This policy allows admins to update the role field of users in their team
CREATE POLICY "Admins can manage roles within their team"
ON users
FOR UPDATE
USING (
  -- Check: current user is admin in same team (using helper function to avoid recursion)
  users.team_id IS NOT NULL
  AND is_admin_in_same_team(users.team_id)
)
WITH CHECK (
  -- Validate the new role value
  role IN ('admin', 'member')
);

CREATE POLICY "Allow user creation" 
  ON users FOR INSERT 
  WITH CHECK (TRUE);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT SELECT ON user_teams TO anon, authenticated;
GRANT ALL ON teams TO anon, authenticated;
GRANT ALL ON users TO anon, authenticated; 