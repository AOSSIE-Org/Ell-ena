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
-- Enforce created_by = auth.uid() so users can't spoof creator
-- Also validate that assigned_to is in the same team (or NULL)
DROP POLICY IF EXISTS "Users can create tasks in their team" ON tasks;
CREATE POLICY "Users can create tasks in their team"
  ON tasks FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.team_id = team_id
    )
    AND (
      assigned_to IS NULL
      OR EXISTS (
        SELECT 1 FROM users
        WHERE users.id = assigned_to
          AND users.team_id = team_id
      )
    )
  );

-- Users can update tasks ONLY if they are:
-- the creator (and still in same team), OR the assignee (and still in same team), OR an admin in the same team
-- Note: This policy grants UPDATE permission, but sensitive column changes
-- are further restricted by the guard_task_changes trigger
DROP POLICY IF EXISTS "Users can update tasks they created or are assigned to" ON tasks;
CREATE POLICY "Users can update tasks they created or are assigned to"
  ON tasks FOR UPDATE
  USING (
    -- Creator branch: must be creator AND still be in the same team
    (
      created_by = auth.uid() 
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
          AND users.team_id = tasks.team_id
      )
    )
    -- Assignee branch: must be assigned_to AND still be in the same team
    OR (
      assigned_to = auth.uid()
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
          AND users.team_id = tasks.team_id
      )
    )
    -- Admin branch: must be admin in the same team
    OR EXISTS (
      SELECT 1 FROM users
      WHERE users.id = auth.uid()
        AND users.role = 'admin'
        AND users.team_id = tasks.team_id
    )
  )
  WITH CHECK (
    -- Creator branch: must be creator AND still be in the same team
    (
      created_by = auth.uid() 
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
          AND users.team_id = tasks.team_id
      )
    )
    -- Assignee branch: must be assigned_to AND still be in the same team
    OR (
      assigned_to = auth.uid()
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
          AND users.team_id = tasks.team_id
      )
    )
    -- Admin branch: must be admin in the same team
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
    -- Creator branch: must be creator AND still be in the same team
    (
      created_by = auth.uid() 
      AND EXISTS (
        SELECT 1 FROM users
        WHERE users.id = auth.uid()
          AND users.team_id = tasks.team_id
      )
    )
    -- Admin branch: must be admin in the same team
    OR EXISTS (
      SELECT 1 FROM users
      WHERE id = auth.uid()
        AND role = 'admin'
        AND team_id = tasks.team_id
    )
  );

-- Create function to check if current user is an admin of a specific team
-- SECURITY DEFINER with explicit search_path and schema-qualified table references
CREATE OR REPLACE FUNCTION is_user_admin_of_team(team_uuid UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
      AND team_id = team_uuid
  );
END;
$$ LANGUAGE plpgsql;

-- Create function to check if a user belongs to a specific team
-- SECURITY DEFINER with explicit search_path and schema-qualified table references
CREATE OR REPLACE FUNCTION is_user_in_team(user_uuid UUID, team_uuid UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  -- Allow NULL user (unassigned)
  IF user_uuid IS NULL THEN
    RETURN TRUE;
  END IF;
  
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = user_uuid
      AND team_id = team_uuid
  );
END;
$$ LANGUAGE plpgsql;

-- Create comprehensive guard trigger for sensitive task changes
CREATE OR REPLACE FUNCTION guard_task_changes()
RETURNS TRIGGER AS $$
DECLARE
  is_admin_of_old_team BOOLEAN;
  is_creator BOOLEAN;
BEGIN
  -- Check if user is creator of the task
  is_creator := (auth.uid() = OLD.created_by);
  
  -- Check admin status for old team
  is_admin_of_old_team := is_user_admin_of_team(OLD.team_id);

  -- Guard 1: Approval status changes (use OLD.team_id for authorization)
  IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
    IF NOT is_admin_of_old_team THEN
      RAISE EXCEPTION 'permission denied: only admins can change approval_status';
    END IF;
  END IF;

  -- Guard 2: Team ID changes (use OLD.team_id for authorization)
  IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
    IF NOT is_admin_of_old_team THEN
      RAISE EXCEPTION 'permission denied: only admins can change team_id';
    END IF;
  END IF;

  -- Guard 3: Assigned_to changes
  IF NEW.assigned_to IS DISTINCT FROM OLD.assigned_to THEN
    -- Only creator or admin can change assigned_to
    IF NOT (is_creator OR is_admin_of_old_team) THEN
      RAISE EXCEPTION 'permission denied: only creator or admin can change assigned_to';
    END IF;
    
    -- Validate that the new assignee belongs to the task's team (using NEW.team_id)
    IF NOT is_user_in_team(NEW.assigned_to, NEW.team_id) THEN
      RAISE EXCEPTION 'permission denied: assignee must be in the same team as the task';
    END IF;
  END IF;

  -- Guard 4: Created_by is immutable
  IF NEW.created_by IS DISTINCT FROM OLD.created_by THEN
    RAISE EXCEPTION 'permission denied: created_by cannot be changed';
  END IF;

  -- Guard 5: Even if assigned_to didn't change, validate that the current assignee (if any) 
  -- belongs to the team (in case team_id changed)
  IF NEW.team_id IS DISTINCT FROM OLD.team_id AND NEW.assigned_to IS NOT NULL THEN
    IF NOT is_user_in_team(NEW.assigned_to, NEW.team_id) THEN
      RAISE EXCEPTION 'permission denied: cannot move task to a team that the assignee does not belong to';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for task changes
DROP TRIGGER IF EXISTS guard_task_changes ON tasks;
CREATE TRIGGER guard_task_changes
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION guard_task_changes();

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
-- Enforce user_id = auth.uid() so they can't post as someone else
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

-- Users can only update their own comments (team-scoped)
DROP POLICY IF EXISTS "Users can only update their own comments" ON task_comments;
CREATE POLICY "Users can only update their own comments"
  ON task_comments FOR UPDATE
  USING (
    -- User must own the comment AND be in the same team as the task
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM tasks
      JOIN users ON users.team_id = tasks.team_id
      WHERE tasks.id = task_comments.task_id
        AND users.id = auth.uid()
    )
  )
  WITH CHECK (
    -- Ensure the update doesn't change ownership and still maintains team scope
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM tasks
      JOIN users ON users.team_id = tasks.team_id
      WHERE tasks.id = task_comments.task_id
        AND users.id = auth.uid()
    )
  );

-- Users can only delete their own comments (team-scoped)
DROP POLICY IF EXISTS "Users can only delete their own comments" ON task_comments;
CREATE POLICY "Users can only delete their own comments"
  ON task_comments FOR DELETE
  USING (
    -- User must own the comment AND be in the same team as the task
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM tasks
      JOIN users ON users.team_id = tasks.team_id
      WHERE tasks.id = task_comments.task_id
        AND users.id = auth.uid()
    )
  );

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

-- Function to check if a user is an admin of a team (kept for backward compatibility)
-- SECURITY DEFINER with explicit search_path and schema-qualified table references
CREATE OR REPLACE FUNCTION is_team_admin(team_uuid UUID)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE id = auth.uid()
      AND role = 'admin'
      AND team_id = team_uuid
  );
END;
$$ LANGUAGE plpgsql;