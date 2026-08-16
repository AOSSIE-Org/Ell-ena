-- Guard against approval_status being changed by non-admins.
--
-- tasks/tickets each have two permissive UPDATE policies: a broad one letting
-- the creator or assignee update the row, and a narrower one intended to
-- restrict approval_status changes to team admins. Postgres RLS ORs all
-- permissive policies for the same command together and has no column-level
-- restriction, so the broad policy alone already allows a non-admin
-- creator/assignee to change approval_status directly -- the "admins only"
-- policy adds no actual restriction. This trigger closes that gap without
-- touching the existing policies.
--
-- team_id changes are also gated to admins of OLD.team_id, otherwise a
-- non-admin could move a row into a team they admin and then approve it
-- in a later update, bypassing the approval_status guard indirectly.

-- Helper: is the current user an admin of the given team?
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

-- Guard trigger for tasks: only a team admin may change approval_status,
-- and only a team admin may move the row to a different team_id. Both
-- checks use OLD.team_id so a concurrent team_id change can't be used to
-- dodge the admin check (e.g. move into a team you admin, then approve).
-- All other field changes by the creator/assignee are left untouched.
CREATE OR REPLACE FUNCTION guard_task_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
    IF NOT is_user_admin_of_team(OLD.team_id) THEN
      RAISE EXCEPTION 'permission denied: only admins can change approval_status';
    END IF;
  END IF;

  IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
    IF NOT is_user_admin_of_team(OLD.team_id) THEN
      RAISE EXCEPTION 'permission denied: only admins can change team_id';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS guard_task_changes ON tasks;
CREATE TRIGGER guard_task_changes
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION guard_task_changes();

-- Guard trigger for tickets: same rules as tasks.
CREATE OR REPLACE FUNCTION guard_ticket_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.approval_status IS DISTINCT FROM OLD.approval_status THEN
    IF NOT is_user_admin_of_team(OLD.team_id) THEN
      RAISE EXCEPTION 'permission denied: only admins can change approval_status';
    END IF;
  END IF;

  IF NEW.team_id IS DISTINCT FROM OLD.team_id THEN
    IF NOT is_user_admin_of_team(OLD.team_id) THEN
      RAISE EXCEPTION 'permission denied: only admins can change team_id';
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS guard_ticket_changes ON tickets;
CREATE TRIGGER guard_ticket_changes
BEFORE UPDATE ON tickets
FOR EACH ROW
EXECUTE FUNCTION guard_ticket_changes();
