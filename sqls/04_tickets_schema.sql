-- Tickets table with IF NOT EXISTS
CREATE TABLE IF NOT EXISTS tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
    category TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'resolved')),
    approval_status TEXT NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
    created_by UUID REFERENCES auth.users(id),
    assigned_to UUID REFERENCES auth.users(id),
    team_id UUID REFERENCES teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Ticket comments table with IF NOT EXISTS
CREATE TABLE IF NOT EXISTS ticket_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES tickets(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes (these are safe with IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS idx_tickets_team_id ON tickets(team_id);
CREATE INDEX IF NOT EXISTS idx_ticket_comments_ticket_id ON ticket_comments(ticket_id);
CREATE INDEX IF NOT EXISTS idx_users_team_id ON users(team_id);

-- Drop existing validation function and trigger
DROP FUNCTION IF EXISTS validate_ticket_user_team() CASCADE;

-- Create validation function
CREATE OR REPLACE FUNCTION validate_ticket_user_team()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.created_by IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM users u
        WHERE u.id = NEW.created_by
          AND u.team_id = NEW.team_id
    ) THEN
        RAISE EXCEPTION 'created_by must belong to the same team as the ticket';
    END IF;

    IF NEW.assigned_to IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM users u
        WHERE u.id = NEW.assigned_to
          AND u.team_id = NEW.team_id
    ) THEN
        RAISE EXCEPTION 'assigned_to must belong to the same team as the ticket';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create validation trigger (drop if exists first)
DROP TRIGGER IF EXISTS trg_validate_ticket_user_team ON tickets;

CREATE TRIGGER trg_validate_ticket_user_team
BEFORE INSERT OR UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION validate_ticket_user_team();

-- Drop existing ticket number trigger
DROP TRIGGER IF EXISTS set_ticket_number ON tickets;

-- Create or replace ticket number function
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    team_prefix TEXT;
    next_number INT;
    ticket_number TEXT;
BEGIN
    SELECT UPPER(SUBSTRING(name FROM 1 FOR 3))
    INTO team_prefix
    FROM teams
    WHERE id = NEW.team_id;
    
    IF team_prefix IS NULL THEN
        team_prefix := 'TKT';
    END IF;
    
    SELECT COALESCE(MAX(SUBSTRING(tickets.ticket_number FROM '[0-9]+')::INT), 0) + 1
    INTO next_number
    FROM tickets
    WHERE tickets.ticket_number LIKE team_prefix || '-%';
    
    ticket_number := team_prefix || '-' || LPAD(next_number::TEXT, 3, '0');
    
    NEW.ticket_number := ticket_number;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create ticket number trigger
CREATE TRIGGER set_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION generate_ticket_number();

-- Drop existing updated_at trigger
DROP TRIGGER IF EXISTS update_tickets_updated_at ON tickets;

-- Create or replace updated_at function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create updated_at trigger
CREATE TRIGGER update_tickets_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS (safe to run multiple times)
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_comments ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies before recreating
DROP POLICY IF EXISTS tickets_view_policy ON tickets;
DROP POLICY IF EXISTS tickets_insert_policy ON tickets;
DROP POLICY IF EXISTS tickets_update_policy ON tickets;
DROP POLICY IF EXISTS tickets_delete_policy ON tickets;

DROP POLICY IF EXISTS ticket_comments_view_policy ON ticket_comments;
DROP POLICY IF EXISTS ticket_comments_insert_policy ON ticket_comments;
DROP POLICY IF EXISTS ticket_comments_update_policy ON ticket_comments;
DROP POLICY IF EXISTS ticket_comments_delete_policy ON ticket_comments;

-- Recreate all policies
CREATE POLICY tickets_view_policy ON tickets
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.team_id = tickets.team_id
        )
    );

CREATE POLICY tickets_insert_policy ON tickets
    FOR INSERT
    WITH CHECK (
        auth.uid() = created_by AND
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.team_id = tickets.team_id
        )
    );

CREATE POLICY tickets_update_policy ON tickets
    FOR UPDATE
    USING (
        auth.uid() = created_by OR 
        auth.uid() = assigned_to OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.team_id = tickets.team_id 
            AND users.role = 'admin'
        )
    );

CREATE POLICY tickets_delete_policy ON tickets
    FOR DELETE
    USING (
        auth.uid() = created_by OR 
        auth.uid() = assigned_to OR
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.team_id = tickets.team_id 
            AND users.role = 'admin'
        )
    );

CREATE POLICY ticket_comments_view_policy ON ticket_comments
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM tickets 
            JOIN users ON users.team_id = tickets.team_id
            WHERE tickets.id = ticket_comments.ticket_id 
            AND users.id = auth.uid()
        )
    );

CREATE POLICY ticket_comments_insert_policy ON ticket_comments
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        EXISTS (
            SELECT 1 FROM tickets 
            JOIN users ON users.team_id = tickets.team_id
            WHERE tickets.id = ticket_comments.ticket_id 
            AND users.id = auth.uid()
        )
    );

CREATE POLICY ticket_comments_update_policy ON ticket_comments
    FOR UPDATE
    USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM tickets 
            JOIN users ON users.team_id = tickets.team_id
            WHERE tickets.id = ticket_comments.ticket_id 
            AND users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );

CREATE POLICY ticket_comments_delete_policy ON ticket_comments
    FOR DELETE
    USING (
        auth.uid() = user_id OR
        EXISTS (
            SELECT 1 FROM tickets 
            JOIN users ON users.team_id = tickets.team_id
            WHERE tickets.id = ticket_comments.ticket_id 
            AND users.id = auth.uid() 
            AND users.role = 'admin'
        )
    );