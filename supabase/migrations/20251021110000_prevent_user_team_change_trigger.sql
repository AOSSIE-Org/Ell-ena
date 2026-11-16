-- Trigger function: block team_id change on users who are referenced in tickets
CREATE OR REPLACE FUNCTION public.prevent_user_team_change_if_tickets_exist()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.team_id IS DISTINCT FROM NEW.team_id THEN
    IF EXISTS (
      SELECT 1 FROM public.tickets
      WHERE created_by = OLD.id OR assigned_to = OLD.id
    ) THEN
      RAISE EXCEPTION 'Cannot change user team: user is referenced in existing tickets as created_by or assigned_to';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER prevent_user_team_change
  BEFORE UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_user_team_change_if_tickets_exist();

-- Trigger function: validate that ticket members belong to the ticket's team
CREATE OR REPLACE FUNCTION public.validate_ticket_team_consistency()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_team UUID;
BEGIN
  SELECT team_id INTO v_team FROM public.users WHERE id = NEW.created_by;
  IF v_team != NEW.team_id THEN
    RAISE EXCEPTION 'Ticket team mismatch: created_by user does not belong to the ticket''s team';
  END IF;

  IF NEW.assigned_to IS NOT NULL THEN
    SELECT team_id INTO v_team FROM public.users WHERE id = NEW.assigned_to;
    IF v_team != NEW.team_id THEN
      RAISE EXCEPTION 'Ticket team mismatch: assigned_to user does not belong to the ticket''s team';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_ticket_team_consistency
  BEFORE INSERT OR UPDATE ON public.tickets
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_ticket_team_consistency();
