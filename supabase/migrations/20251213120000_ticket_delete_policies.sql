-- Add DELETE policies for tickets table
-- Ticket creators can delete their own tickets
CREATE POLICY "Ticket creators can delete their own tickets" 
  ON tickets FOR DELETE 
  USING (created_by = auth.uid());

-- Team admins can delete any ticket in their team
CREATE POLICY "Team admins can delete any ticket in their team" 
  ON tickets FOR DELETE 
  USING (
    auth.uid() IN (
      SELECT id FROM users 
      WHERE team_id = tickets.team_id AND role = 'admin'
    )
  );
