-- Installs uuid-ossp extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;


-- Create teams table
CREATE TABLE teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  team_code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_by UUID NOT NULL,
  admin_name TEXT NOT NULL,
  admin_email TEXT NOT NULL,
  CONSTRAINT team_code_length CHECK (char_length(team_code) = 6)
);

-- Create users table
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  full_name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  team_id UUID REFERENCES teams(id),
  role TEXT NOT NULL CHECK (role IN ('admin', 'member')),
  google_refresh_token TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create RLS (Row Level Security) policies

-- Enable RLS on tables
ALTER TABLE teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policies for teams
CREATE POLICY "Team members can view their team" 
  ON teams FOR SELECT 
  USING (id IN (
    SELECT team_id FROM users WHERE id = auth.uid()
  ));

CREATE POLICY "Only admins can update their team" 
  ON teams FOR UPDATE 
  USING (created_by = auth.uid());

-- Create policies for users
CREATE POLICY "Users can view members of their team" 
  ON users FOR SELECT 
  USING (
    -- Allow users to see themselves
    id = auth.uid() 
    OR 
    -- Allow users to see other members of their team
    (team_id IN (
      SELECT team_id FROM users WHERE id = auth.uid() AND team_id IS NOT NULL
    ))
  );

CREATE POLICY "Users can update their own profile" 
  ON users FOR UPDATE 
  USING (id = auth.uid());

-- Add insert policies
CREATE POLICY "Allow authenticated users to insert users"
  ON users FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated users to insert teams"
  ON teams FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Create functions

-- Function to check if a team code exists
CREATE OR REPLACE FUNCTION check_team_code_exists(code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM teams WHERE team_code = code);
END;
$$;

-- Function to generate a random team code
CREATE OR REPLACE FUNCTION generate_unique_team_code()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
  chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  result TEXT := '';
  i INTEGER := 0;
  is_unique BOOLEAN := FALSE;
BEGIN
  WHILE NOT is_unique LOOP
    result := '';
    FOR i IN 1..6 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    
    is_unique := NOT check_team_code_exists(result);
  END LOOP;
  
  RETURN result;
END;
$$;

-- Create indexes for better performance
CREATE INDEX idx_teams_team_code ON teams(team_code);
CREATE INDEX idx_users_team_id ON users(team_id);
CREATE INDEX idx_users_email ON users(email);