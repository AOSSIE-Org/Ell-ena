-- Teams table
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL
);

-- Tickets table
CREATE TABLE tickets (
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

-- Functional index for faster prefix-based lookups
CREATE INDEX idx_tickets_prefix_number ON tickets(
    (SUBSTRING(ticket_number FROM '^[A-Z]+')),
    (SUBSTRING(ticket_number FROM '[0-9]+$')::INT)
);

-- Core fix: generate ticket number safely using advisory locks
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    team_prefix TEXT;
    next_number INT;
    lock_key BIGINT;
BEGIN
    -- Handle NULL team_id safely
    IF NEW.team_id IS NULL THEN
        team_prefix := 'TKT';
    ELSE
        SELECT UPPER(SUBSTRING(name FROM 1 FOR 3))
        INTO team_prefix
        FROM teams
        WHERE id = NEW.team_id;

        IF team_prefix IS NULL OR team_prefix = '' THEN
            team_prefix := 'TKT';
        END IF;

        lock_key := hashtext(NEW.team_id::TEXT)::BIGINT;
        PERFORM pg_advisory_xact_lock(lock_key);
    END IF;

    -- Defensive MAX calculation (ignore malformed ticket numbers)
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

    NEW.ticket_number := team_prefix || '-' || LPAD(next_number::TEXT, 3, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to assign ticket number before insert
CREATE TRIGGER set_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION generate_ticket_number();