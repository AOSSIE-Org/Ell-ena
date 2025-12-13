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

CREATE TABLE ticket_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID REFERENCES tickets(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Create indexes for performance optimization
-- These indexes improve RLS policy checks and query performance
CREATE INDEX idx_tickets_team_id ON tickets(team_id);
CREATE INDEX idx_tickets_created_by ON tickets(created_by);
CREATE INDEX idx_tickets_assigned_to ON tickets(assigned_to);
CREATE INDEX idx_tickets_status ON tickets(status);
CREATE INDEX idx_tickets_approval_status ON tickets(approval_status);
CREATE INDEX idx_ticket_comments_ticket_id ON ticket_comments(ticket_id);
CREATE INDEX idx_ticket_comments_user_id ON ticket_comments(user_id);

-- Function to validate that assigned_to user belongs to the same team
CREATE OR REPLACE FUNCTION validate_ticket_assignment()
RETURNS TRIGGER AS $$
BEGIN
    -- If assigned_to is NULL, skip validation
    IF NEW.assigned_to IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Check if assigned_to user belongs to the same team
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = NEW.assigned_to 
        AND team_id = NEW.team_id
    ) THEN
        RAISE EXCEPTION 'Cannot assign ticket to user outside the team';
    END IF;
    
    -- Check if created_by user belongs to the same team
    IF NEW.created_by IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = NEW.created_by 
        AND team_id = NEW.team_id
    ) THEN
        RAISE EXCEPTION 'Creator must belong to the ticket team';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce team consistency for ticket assignments
CREATE TRIGGER validate_ticket_assignment_trigger
BEFORE INSERT OR UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION validate_ticket_assignment();

-- Function to validate that comment user belongs to the ticket's team
CREATE OR REPLACE FUNCTION validate_comment_user()
RETURNS TRIGGER AS $$
DECLARE
    ticket_team_id UUID;
BEGIN
    -- Get the team_id of the ticket
    SELECT team_id INTO ticket_team_id
    FROM tickets
    WHERE id = NEW.ticket_id;
    
    -- Check if user belongs to the same team
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = NEW.user_id 
        AND team_id = ticket_team_id
    ) THEN
        RAISE EXCEPTION 'Cannot add comment from user outside the ticket team';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to enforce team consistency for comments
CREATE TRIGGER validate_comment_user_trigger
BEFORE INSERT OR UPDATE ON ticket_comments
FOR EACH ROW
EXECUTE FUNCTION validate_comment_user();

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

CREATE TRIGGER set_ticket_number
BEFORE INSERT ON tickets
FOR EACH ROW
EXECUTE FUNCTION generate_ticket_number();

ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;

CREATE POLICY tickets_view_policy ON tickets
    FOR SELECT
    USING (
        team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    );

CREATE POLICY tickets_insert_policy ON tickets
    FOR INSERT
    WITH CHECK (
        auth.uid() = created_by AND
        team_id IN (
            SELECT team_id FROM users WHERE id = auth.uid()
        )
    );

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

ALTER TABLE ticket_comments ENABLE ROW LEVEL SECURITY;

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

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_tickets_updated_at
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column(); 