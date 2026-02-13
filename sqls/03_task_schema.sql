-- Create tasks table
CREATE TABLE tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL CHECK (status IN ('todo', 'in_progress', 'completed')),
  approval_status TEXT NOT NULL DEFAULT 'pending' CHECK (approval_status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  due_date TIMESTAMP WITH TIME ZONE,
  team_id UUID REFERENCES teams(id),
  created_by UUID REFERENCES auth.users(id),
  assigned_to UUID REFERENCES auth.users(id)
);

-- Create task comments table for communication
CREATE TABLE task_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_tasks_team_id ON tasks(team_id);
CREATE INDEX idx_tasks_created_by ON tasks(created_by);
CREATE INDEX idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_approval_status ON tasks(approval_status);
CREATE INDEX idx_task_comments_task_id ON task_comments(task_id);

-- Enable RLS on tasks table
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments ENABLE ROW LEVEL SECURITY;

-- Create policies for tasks

-- Users can view all tasks in their team
DROP POLICY IF EXISTS "Users can view tasks in their team" ON tasks;
CREATE POLICY "Users can view tasks in their team"
  ON tasks FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.team_id = tasks.team_id
    )
  );

-- Users can create tasks in their team
-- (also enforce created_by = auth.uid() so users can't spoof creator)
DROP POLICY IF EXISTS "Users can create tasks in their team" ON tasks;
CREATE POLICY "Users can create tasks in their team"
  ON tasks FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.team_id = tasks.team_id
    )
  );

-- Users can update tasks ONLY if they are:
--  - the creator, OR
--  - the assignee, OR
--  - an admin in the same team
--
-- IMPORTANT: Removed the old "any team member can update" logic.
DROP POLICY IF EXISTS "Users can update tasks they created or are assigned to" ON tasks;
CREATE POLICY "Users can update tasks they created or are assigned to"
  ON tasks FOR UPDATE
  USING (
    created_by = auth.uid()
    OR assigned_to = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
        AND users.team_id = tasks.team_id
    )
  )
  WITH CHECK (
    created_by = auth.uid()
    OR assigned_to = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
        AND users.team_id = tasks.team_id
    )
  );

-- Users can delete tasks they created OR admins can delete any task in their team
DROP POLICY IF EXISTS "Users can delete tasks they created or admins can delete" ON tasks;
CREATE POLICY "Users can delete tasks they created or admins can delete"
  ON tasks FOR DELETE
  USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
        AND role = 'admin'
        AND team_id = tasks.team_id
    )
  );

-- Remove this policy because policies are OR-ed:
-- Keeping it does NOT prevent non-admins from updating approval_status if another update policy allows them.
DROP POLICY IF EXISTS "Only admins can approve or reject tasks" ON tasks;

-- Create policies for task comments

-- Users can view comments on tasks in their team
DROP POLICY IF EXISTS "Users can view comments on tasks in their team" ON task_comments;
CREATE POLICY "Users can view comments on tasks in their team"
  ON task_comments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM tasks
      JOIN users ON users.team_id = tasks.team_id
      WHERE tasks.id = task_comments.task_id
        AND users.id = auth.uid()
    )
  );

-- Users can add comments to tasks in their team
-- (also enforce user_id = auth.uid() so they can't post as someone else)
DROP POLICY IF EXISTS "Users can add comments to tasks in their team" ON task_comments;
CREATE POLICY "Users can add comments to tasks in their team"
  ON task_comments FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM tasks
      JOIN users ON users.team_id = tasks.team_id
      WHERE tasks.id = task_comments.task_id
        AND users.id = auth.uid()
    )
  );

-- Users can only update their own comments
DROP POLICY IF EXISTS "Users can only update their own comments" ON task_comments;
CREATE POLICY "Users can only update their own comments"
  ON task_comments FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can only delete their own comments
DROP POLICY IF EXISTS "Users can only delete their own comments" ON task_comments;
CREATE POLICY "Users can only delete their own comments"
  ON task_comments FOR DELETE
  USING (user_id = auth.uid());

-- Create function to update task timestamps
CREATE OR REPLACE FUNCTION update_task_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update task timestamps
DROP TRIGGER IF EXISTS update_task_timestamp ON tasks;
CREATE TRIGGER update_task_timestamp
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION update_task_timestamp();

-- Function to check if a user is an admin of a team
CREATE OR REPLACE FUNCTION is_team_admin(team_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE id = auth.uid()
      AND role = 'admin'
      AND team_id = team_uuid
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
