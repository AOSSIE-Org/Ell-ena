-- Teams table
CREATE TABLE IF NOT EXISTS teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id),
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('member', 'admin')),
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Tickets table
CREATE TABLE IF NOT EXISTS tickets (
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
    team_id UUID NOT NULL REFERENCES teams(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Ticket comments table
CREATE TABLE IF NOT EXISTS ticket_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes for RLS performance
CREATE INDEX IF NOT EXISTS idx_tickets_team_id ON tickets(team_id);
CREATE INDEX IF NOT EXISTS idx_ticket_comments_ticket_id ON ticket_comments(ticket_id);
CREATE INDEX IF NOT EXISTS idx_users_team_id ON users(team_id);

-- Optional indexes for query optimization
CREATE INDEX IF NOT EXISTS idx_users_id_team_id ON users(id, team_id);
CREATE INDEX IF NOT EXISTS idx_tickets_team_status ON tickets(team_id, status);
CREATE INDEX IF NOT EXISTS idx_tickets_team_created ON tickets(team_id, created_at);
CREATE INDEX IF NOT EXISTS idx_tickets_created_by ON tickets(created_by);
CREATE INDEX IF NOT EXISTS idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_ticket_comments_user_id ON ticket_comments(user_id);

-- Ticket number generator function
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    team_prefix TEXT;
    next_number INT;
    lock_key BIGINT;
BEGIN

    -- Get team prefix
    SELECT UPPER(SUBSTRING(name FROM 1 FOR 3))
    INTO team_prefix
    FROM teams
    WHERE id = NEW.team_id;

    IF team_prefix IS NULL OR team_prefix = '' THEN
        team_prefix := 'TKT';
    END IF;


    lock_key := ('x' || replace(NEW.team_id::text, '-', ''))::bit(64)::bigint;
    PERFORM pg_advisory_xact_lock(lock_key);

    SELECT COALESCE(
        MAX(
            CASE
                WHEN ticket_number ~ ('^' || team_prefix || '-[0-9]+$')
                THEN SUBSTRING(ticket_number FROM '[0-9]+$')::INT
                ELSE NULL
            END
        ),
        0
    ) + 1
    INTO next_number
    FROM tickets
    WHERE ticket_number LIKE team_prefix || '-%';

    NEW.ticket_number := team_prefix || '-' || LPAD(next_number::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for ticket number generation
CREATE TRIGGER set_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION generate_ticket_number();

-- Data integrity validation function
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

ALTER TABLE ticket_comments ENABLE ROW LEVEL SECURITY;

-- Trigger for data integrity validation
CREATE TRIGGER trg_validate_ticket_user_team
BEFORE INSERT OR UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION validate_ticket_user_team();

-- Updated_at auto-update function

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

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at auto-update
CREATE TRIGGER update_tickets_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_teams_updated_at
BEFORE UPDATE ON teams
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE ticket_comments ENABLE ROW LEVEL SECURITY;

-- Tickets RLS policies
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
    auth.uid() = created_by
    AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.team_id = tickets.team_id
    )
);

CREATE POLICY tickets_update_policy ON tickets
FOR UPDATE
USING (
    auth.uid() = created_by
    OR auth.uid() = assigned_to
    OR EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.team_id = tickets.team_id
        AND users.role = 'admin'
    )
)
WITH CHECK (
    auth.uid() = created_by
    OR auth.uid() = assigned_to
    OR EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
        AND users.team_id = tickets.team_id
        AND users.role = 'admin'
    )
);

-- Ticket comments RLS policies
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
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM tickets
        JOIN users ON users.team_id = tickets.team_id
        WHERE tickets.id = ticket_comments.ticket_id
        AND users.id = auth.uid()
    )
);

CREATE POLICY ticket_comments_update_policy ON ticket_comments
FOR UPDATE
USING (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM tickets
        JOIN users ON users.team_id = tickets.team_id
        WHERE tickets.id = ticket_comments.ticket_id
        AND users.id = auth.uid()
    )
);

CREATE POLICY ticket_comments_delete_policy ON ticket_comments
FOR DELETE
USING (
    auth.uid() = user_id
    OR EXISTS (
        SELECT 1 FROM tickets
        JOIN users ON users.team_id = tickets.team_id
        WHERE tickets.id = ticket_comments.ticket_id
        AND users.id = auth.uid()
        AND users.role = 'admin'
    )
);
