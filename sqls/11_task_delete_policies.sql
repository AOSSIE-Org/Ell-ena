-- Add DELETE policies for tasks table
-- Task creators can delete their own tasks
CREATE POLICY "Task creators can delete their own tasks" 
  ON tasks FOR DELETE 
  USING (created_by = auth.uid());

-- Team admins can delete any task in their team
CREATE POLICY "Team admins can delete any task in their team" 
  ON tasks FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM users 
      WHERE id = auth.uid() 
      AND role = 'admin' 
      AND team_id = tasks.team_id
    )
  );
