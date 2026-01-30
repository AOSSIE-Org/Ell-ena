-- Tickets table
CREATE TABLE tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_number TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high')),
    category TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open'
        CHECK (status IN ('open', 'in_progress', 'resolved')),
    approval_status TEXT NOT NULL DEFAULT 'pending'
        CHECK (approval_status IN ('pending', 'approved', 'rejected')),
    created_by UUID REFERENCES auth.users(id),
    assigned_to UUID REFERENCES auth.users(id),
    team_id UUID REFERENCES teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Indexes for ticket_number
-- Prefix index (ABC-)
CREATE INDEX idx_tickets_prefix ON tickets (
    (SUBSTRING(ticket_number FROM '^[A-Z]+'))
);

-- Numeric suffix index (-001)
CREATE INDEX idx_tickets_number_suffix ON tickets (
    (
        CASE
            WHEN ticket_number ~ '^[A-Z]+-[0-9]+$'
            THEN SUBSTRING(ticket_number FROM '[0-9]+$')::INT
            ELSE NULL
        END
    )
);

-- Ticket number generator
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    team_prefix TEXT;
    sanitized_prefix TEXT;
    next_number INT;
    lock_key BIGINT;
BEGIN
    -- Determine team prefix
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
    END IF;

    -- Sanitize team_prefix to prevent LIKE/regex injection
    -- Remove any non-alphabetic characters and limit to 3 uppercase letters
    sanitized_prefix := UPPER(regexp_replace(team_prefix, '[^A-Za-z]', '', 'g'));
    IF sanitized_prefix = '' OR length(sanitized_prefix) < 3 THEN
        sanitized_prefix := 'TKT';
    ELSE
        sanitized_prefix := SUBSTRING(sanitized_prefix FROM 1 FOR 3);
    END IF;

    -- Serialize inserts per prefix
    lock_key := hashtext(sanitized_prefix)::BIGINT;
    PERFORM pg_advisory_xact_lock(lock_key);

    -- Safely calculate next ticket number using sanitized prefix
    -- Escape LIKE special characters by using regex pattern
    SELECT COALESCE(
        MAX(
            CASE
                -- Use regex for exact prefix matching (sanitized_prefix is safe)
                WHEN ticket_number ~ ('^' || sanitized_prefix || '-[0-9]+$')
                THEN SUBSTRING(ticket_number FROM '[0-9]+$')::INT
                ELSE NULL
            END
        ),
        0
    ) + 1
    INTO next_number
    FROM tickets
    WHERE ticket_number LIKE sanitized_prefix || '-%';

    NEW.ticket_number :=
        sanitized_prefix || '-' || LPAD(next_number::TEXT, 3, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: assign ticket number
CREATE TRIGGER set_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION generate_ticket_number();

-- updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tickets_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS)
ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

-- View tickets (same team)
CREATE POLICY tickets_view_policy ON tickets
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1
            FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = tickets.team_id
        )
    );

-- Insert tickets
CREATE POLICY tickets_insert_policy ON tickets
    FOR INSERT
    WITH CHECK (
        -- Creator must be authenticated and in the same team
        auth.uid() = created_by
        AND EXISTS (
            SELECT 1
            FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = tickets.team_id
        )
    );

-- Update tickets - Fixed with team membership checks
CREATE POLICY tickets_update_policy ON tickets
    FOR UPDATE
    USING (
        -- created_by can update only if they're still in the same team
        (
            auth.uid() = created_by 
            AND EXISTS (
                SELECT 1
                FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = tickets.team_id
            )
        )
        OR
        -- assigned_to can update only if they're still in the same team
        (
            auth.uid() = assigned_to 
            AND EXISTS (
                SELECT 1
                FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = tickets.team_id
            )
        )
        OR
        -- Admins from the same team
        EXISTS (
            SELECT 1
            FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = tickets.team_id
              AND users.role = 'admin'
        )
    )
    WITH CHECK (
        -- Same conditions for new values
        (
            auth.uid() = created_by 
            AND EXISTS (
                SELECT 1
                FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = tickets.team_id
            )
        )
        OR
        (
            auth.uid() = assigned_to 
            AND EXISTS (
                SELECT 1
                FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = tickets.team_id
            )
        )
        OR
        EXISTS (
            SELECT 1
            FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = tickets.team_id
              AND users.role = 'admin'
        )
    );

-- Delete tickets - Fixed with team membership checks
CREATE POLICY tickets_delete_policy ON tickets
    FOR DELETE
    USING (
        -- created_by can delete only if they're still in the same team
        (
            auth.uid() = created_by 
            AND EXISTS (
                SELECT 1
                FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = tickets.team_id
            )
        )
        OR
        -- assigned_to can delete only if they're still in the same team
        (
            auth.uid() = assigned_to 
            AND EXISTS (
                SELECT 1
                FROM users
                WHERE users.id = auth.uid()
                  AND users.team_id = tickets.team_id
            )
        )
        OR
        -- Admins from the same team
        EXISTS (
            SELECT 1
            FROM users
            WHERE users.id = auth.uid()
              AND users.team_id = tickets.team_id
              AND users.role = 'admin'
        )
    );