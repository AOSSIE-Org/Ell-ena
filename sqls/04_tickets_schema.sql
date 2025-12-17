-- Teams table (required for team prefix lookup)
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL
);

-- Tickets table
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
    team_id UUID REFERENCES teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Index for ticket number lookups
CREATE INDEX idx_tickets_ticket_number ON tickets(ticket_number);

-- Core fix: generate ticket number safely using advisory locks
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    team_prefix TEXT;
    next_number INT;
    lock_key BIGINT;
BEGIN
    -- Get team prefix (first 3 letters of team name)
    SELECT UPPER(SUBSTRING(name FROM 1 FOR 3))
    INTO team_prefix
    FROM teams
    WHERE id = NEW.team_id;

    IF team_prefix IS NULL THEN
        team_prefix := 'TKT';
    END IF;

    -- Advisory lock per team prefix using a more collision-resistant key
    -- Use a combination of ascii values to reduce collision risk
    lock_key := (
        ascii(substring(team_prefix from 1 for 1)) * 1000000 +
        ascii(substring(team_prefix from 2 for 1)) * 1000 +
        ascii(substring(team_prefix from 3 for 1))
    )::BIGINT;
    
    PERFORM pg_advisory_xact_lock(lock_key);

    -- Safely calculate next ticket number for this specific team prefix
    SELECT COALESCE(MAX(
        CASE 
            WHEN SUBSTRING(ticket_number FROM '^[A-Z]+') = team_prefix
            THEN SUBSTRING(ticket_number FROM '[0-9]+$')::INT
        END
    ), 0) + 1
    INTO next_number
    FROM tickets
    WHERE ticket_number LIKE team_prefix || '-%';

    -- Assign ticket number
    NEW.ticket_number := team_prefix || '-' || LPAD(next_number::TEXT, 3, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to assign ticket number before insert
CREATE TRIGGER set_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION generate_ticket_number();