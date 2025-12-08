-- Teams table (unchanged)
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Users table for team memberships
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT auth.uid(),
    team_id UUID REFERENCES teams(id),
    role TEXT NOT NULL CHECK (role IN ('member', 'admin')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Tickets table
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number TEXT NOT NULL UNIQUE,
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

-- Create index for faster ticket_number lookups
CREATE INDEX idx_tickets_ticket_number ON tickets(ticket_number);
CREATE INDEX idx_tickets_team_prefix ON tickets((SUBSTRING(ticket_number FROM '^[A-Z]+')));

-- Ticket comments table
CREATE TABLE ticket_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES tickets(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Function to generate advisory lock key based on team prefix
CREATE OR REPLACE FUNCTION get_team_lock_key(team_prefix TEXT)
RETURNS INTEGER AS $$
BEGIN
    -- Generate a consistent integer hash from team prefix
    RETURN ('x' || lpad(md5(team_prefix), 16, '0'))::bit(32)::int;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Improved generate_ticket_number function with advisory lock
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    team_prefix TEXT;
    next_number INT;
    ticket_number TEXT;
    lock_key INTEGER;
    max_retries INTEGER := 3;
    retry_count INTEGER := 0;
    retry_delay INTERVAL := '50 milliseconds';
BEGIN
    -- Get team prefix
    SELECT UPPER(SUBSTRING(name FROM 1 FOR 3))
    INTO team_prefix
    FROM teams
    WHERE id = NEW.team_id;
    
    IF team_prefix IS NULL THEN
        team_prefix := 'TKT';
    END IF;
    
    -- Get advisory lock key for this team prefix
    lock_key := get_team_lock_key(team_prefix);
    
    -- Try with retry logic in case of lock contention
    WHILE retry_count < max_retries LOOP
        BEGIN
            -- Attempt to acquire advisory lock for this specific team prefix
            IF pg_try_advisory_xact_lock(lock_key) THEN
                -- Lock acquired, safely calculate next number
                SELECT COALESCE(MAX(
                    CASE 
                        WHEN ticket_number ~ (team_prefix || '-[0-9]+$')
                        THEN SUBSTRING(ticket_number FROM team_prefix || '-([0-9]+)$')::INT
                    END
                ), 0) + 1
                INTO next_number
                FROM tickets
                WHERE ticket_number LIKE team_prefix || '-%';
                
                -- Generate ticket number
                ticket_number := team_prefix || '-' || LPAD(next_number::TEXT, 3, '0');
                
                -- Verify uniqueness (additional safety check)
                PERFORM 1 FROM tickets WHERE ticket_number = ticket_number;
                IF FOUND THEN
                    -- This should never happen with the lock, but handle it gracefully
                    RAISE EXCEPTION 'Duplicate ticket number generated: %', ticket_number;
                END IF;
                
                NEW.ticket_number := ticket_number;
                RETURN NEW;
            ELSE
                -- Lock not available, wait and retry
                retry_count := retry_count + 1;
                IF retry_count < max_retries THEN
                    PERFORM pg_sleep(EXTRACT(EPOCH FROM retry_delay));
                END IF;
            END IF;
        EXCEPTION
            WHEN unique_violation THEN
                -- If somehow we get a duplicate, retry with next number
                IF retry_count < max_retries THEN
                    retry_count := retry_count + 1;
                    PERFORM pg_sleep(EXTRACT(EPOCH FROM retry_delay));
                ELSE
                    RAISE;
                END IF;
        END;
    END LOOP;
    
    -- If we get here, we couldn't acquire the lock after max retries
    RAISE EXCEPTION 'Could not acquire lock for ticket number generation after % attempts', max_retries;
END;
$$ LANGUAGE plpgsql;

-- Alternative solution using sequence per team (commented out - choose one approach)
/*
-- Create sequences table for team-specific sequences
CREATE TABLE team_sequences (
    team_prefix TEXT PRIMARY KEY,
    last_number INTEGER NOT NULL DEFAULT 0
);

-- Alternative generate_ticket_number using team sequences
CREATE OR REPLACE FUNCTION generate_ticket_number_seq()
RETURNS TRIGGER AS $$
DECLARE
    team_prefix TEXT;
    next_number INT;
    ticket_number TEXT;
BEGIN
    -- Get team prefix
    SELECT UPPER(SUBSTRING(name FROM 1 FOR 3))
    INTO team_prefix
    FROM teams
    WHERE id = NEW.team_id;
    
    IF team_prefix IS NULL THEN
        team_prefix := 'TKT';
    END IF;
    
    -- Use upsert to get next number atomically
    INSERT INTO team_sequences (team_prefix, last_number)
    VALUES (team_prefix, 1)
    ON CONFLICT (team_prefix) 
    DO UPDATE SET last_number = team_sequences.last_number + 1
    RETURNING last_number INTO next_number;
    
    -- Generate ticket number
    ticket_number := team_prefix || '-' || LPAD(next_number::TEXT, 3, '0');
    
    NEW.ticket_number := ticket_number;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
*/

-- Create trigger
CREATE TRIGGER set_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION generate_ticket_number();

-- Row Level Security Policies
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- View policy
CREATE POLICY tickets_view_policy ON tickets
    FOR SELECT
    USING (
        team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    );

-- Insert policy
CREATE POLICY tickets_insert_policy ON tickets
    FOR INSERT
    WITH CHECK (
        auth.uid() = created_by AND
        team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    );

-- Update policy
CREATE POLICY tickets_update_policy ON tickets
    FOR UPDATE
    USING (
        auth.uid() = created_by OR 
        auth.uid() = assigned_to OR
        auth.uid() IN (
            SELECT id FROM users 
            WHERE team_id = tickets.team_id AND role = 'admin'
        )
    );

-- Ticket comments RLS
ALTER TABLE ticket_comments ENABLE ROW LEVEL SECURITY;

-- Comments view policy
CREATE POLICY ticket_comments_view_policy ON ticket_comments
    FOR SELECT
    USING (
        ticket_id IN (
            SELECT id FROM tickets 
            WHERE team_id IN (
                SELECT team_id FROM users WHERE id = auth.uid()
            )
        )
    );

-- Comments insert policy
CREATE POLICY ticket_comments_insert_policy ON ticket_comments
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id AND
        ticket_id IN (
            SELECT id FROM tickets 
            WHERE team_id IN (
                SELECT team_id FROM users WHERE id = auth.uid()
            )
        )
    );

-- Updated timestamp function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Updated timestamp trigger
CREATE TRIGGER update_tickets_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Helper function to get next ticket number for testing
CREATE OR REPLACE FUNCTION get_next_ticket_number(team_id_param UUID)
RETURNS TEXT AS $$
DECLARE
    team_prefix TEXT;
    next_number INT;
    ticket_number TEXT;
    lock_key INTEGER;
BEGIN
    -- Get team prefix
    SELECT UPPER(SUBSTRING(name FROM 1 FOR 3))
    INTO team_prefix
    FROM teams
    WHERE id = team_id_param;
    
    IF team_prefix IS NULL THEN
        team_prefix := 'TKT';
    END IF;
    
    -- Get advisory lock key
    lock_key := get_team_lock_key(team_prefix);
    
    -- Acquire lock
    PERFORM pg_advisory_xact_lock(lock_key);
    
    -- Calculate next number
    SELECT COALESCE(MAX(
        CASE 
            WHEN ticket_number ~ (team_prefix || '-[0-9]+$')
            THEN SUBSTRING(ticket_number FROM team_prefix || '-([0-9]+)$')::INT
        END
    ), 0) + 1
    INTO next_number
    FROM tickets
    WHERE ticket_number LIKE team_prefix || '-%';
    
    -- Generate ticket number
    ticket_number := team_prefix || '-' || LPAD(next_number::TEXT, 3, '0');
    
    RETURN ticket_number;
END;
$$ LANGUAGE plpgsql;