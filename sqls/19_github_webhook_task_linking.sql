-- Mirrors supabase/migrations/20260928120000_github_webhook_task_linking.sql
-- Optional task-to-ticket link and webhook delivery lifecycle.

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS ticket_id UUID REFERENCES tickets(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_tasks_ticket_id ON tasks (ticket_id);

COMMENT ON COLUMN tasks.ticket_id IS
  'Optional ticket this task belongs to. NULL means the task is not linked. At most one ticket per task; a ticket may have many tasks.';

CREATE OR REPLACE FUNCTION enforce_task_ticket_same_team()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  ticket_team UUID;
BEGIN
  IF NEW.ticket_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT team_id INTO ticket_team
  FROM tickets
  WHERE id = NEW.ticket_id;

  IF ticket_team IS NULL THEN
    RAISE EXCEPTION 'Linked ticket does not exist';
  END IF;

  IF NEW.team_id IS DISTINCT FROM ticket_team THEN
    RAISE EXCEPTION 'Task and linked ticket must belong to the same team';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tasks_ticket_same_team ON tasks;

CREATE TRIGGER tasks_ticket_same_team
  BEFORE INSERT OR UPDATE OF ticket_id, team_id ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION enforce_task_ticket_same_team();

ALTER TABLE webhook_events
  ADD COLUMN IF NOT EXISTS status TEXT,
  ADD COLUMN IF NOT EXISTS error TEXT,
  ADD COLUMN IF NOT EXISTS processed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;

UPDATE webhook_events
SET
  status = 'completed',
  processed_at = COALESCE(processed_at, created_at),
  claimed_at = COALESCE(claimed_at, created_at)
WHERE status IS NULL;

ALTER TABLE webhook_events
  ALTER COLUMN status SET DEFAULT 'processing';

ALTER TABLE webhook_events
  ALTER COLUMN status SET NOT NULL;

ALTER TABLE webhook_events
  DROP CONSTRAINT IF EXISTS webhook_events_status_check;

ALTER TABLE webhook_events
  ADD CONSTRAINT webhook_events_status_check
  CHECK (status IN ('processing', 'completed', 'failed'));

COMMENT ON COLUMN webhook_events.status IS
  'processing while a delivery is claimed, completed after task updates succeed, failed when processing can be retried.';

COMMENT ON COLUMN webhook_events.error IS
  'Sanitized failure detail for a failed delivery. NULL when there is no current error.';

COMMENT ON COLUMN webhook_events.processed_at IS
  'When the delivery was successfully finished. NULL until completion.';

COMMENT ON COLUMN webhook_events.claimed_at IS
  'When the current processing claim was taken. Used to detect stale claims and to ignore late writers.';

CREATE OR REPLACE FUNCTION claim_github_webhook_delivery(
  p_delivery_id TEXT,
  p_stale_seconds INT DEFAULT 300
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  existing webhook_events%ROWTYPE;
  inserted_id UUID;
BEGIN
  IF p_delivery_id IS NULL OR length(trim(p_delivery_id)) = 0 THEN
    RAISE EXCEPTION 'delivery_id is required';
  END IF;

  INSERT INTO webhook_events (delivery_id, status, claimed_at, error)
  VALUES (trim(p_delivery_id), 'processing', now(), NULL)
  ON CONFLICT (delivery_id) DO NOTHING
  RETURNING id INTO inserted_id;

  IF inserted_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'claimed', true,
      'status', 'processing',
      'claim_token', (SELECT claimed_at FROM webhook_events WHERE id = inserted_id)
    );
  END IF;

  SELECT * INTO existing
  FROM webhook_events
  WHERE delivery_id = trim(p_delivery_id)
  FOR UPDATE;

  IF existing.status = 'completed' THEN
    RETURN jsonb_build_object(
      'claimed', false,
      'status', 'completed',
      'duplicate', true
    );
  END IF;

  IF existing.status = 'failed'
     OR (
       existing.status = 'processing'
       AND existing.claimed_at IS NOT NULL
       AND existing.claimed_at < now() - make_interval(secs => GREATEST(p_stale_seconds, 1))
     ) THEN
    UPDATE webhook_events
    SET status = 'processing',
        error = NULL,
        claimed_at = now(),
        processed_at = NULL
    WHERE id = existing.id
    RETURNING claimed_at INTO existing.claimed_at;

    RETURN jsonb_build_object(
      'claimed', true,
      'status', 'processing',
      'recovered', true,
      'claim_token', existing.claimed_at
    );
  END IF;

  RETURN jsonb_build_object(
    'claimed', false,
    'status', existing.status,
    'concurrent', true
  );
END;
$$;

CREATE OR REPLACE FUNCTION complete_github_webhook_delivery(
  p_delivery_id TEXT,
  p_claim_token TIMESTAMPTZ,
  p_repo TEXT,
  p_pr_url TEXT,
  p_completed_at TIMESTAMPTZ,
  p_issue_numbers BIGINT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  delivery webhook_events%ROWTYPE;
  matched_tickets INT := 0;
  completed_tasks INT := 0;
  already_completed INT := 0;
BEGIN
  SELECT * INTO delivery
  FROM webhook_events
  WHERE delivery_id = trim(p_delivery_id)
  FOR UPDATE;

  IF NOT FOUND
     OR delivery.status IS DISTINCT FROM 'processing'
     OR delivery.claimed_at IS DISTINCT FROM p_claim_token THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'stale_claim');
  END IF;

  SELECT COUNT(*) INTO matched_tickets
  FROM tickets
  WHERE gh_repo = p_repo
    AND gh_issue_id = ANY(COALESCE(p_issue_numbers, ARRAY[]::BIGINT[]));

  SELECT COUNT(*) INTO already_completed
  FROM tasks t
  JOIN tickets tk ON tk.id = t.ticket_id
  WHERE tk.gh_repo = p_repo
    AND tk.gh_issue_id = ANY(COALESCE(p_issue_numbers, ARRAY[]::BIGINT[]))
    AND t.status = 'completed';

  UPDATE tasks t
  SET status = 'completed',
      gh_pr_url = p_pr_url,
      completed_at = p_completed_at,
      updated_at = now()
  FROM tickets tk
  WHERE t.ticket_id = tk.id
    AND tk.gh_repo = p_repo
    AND tk.gh_issue_id = ANY(COALESCE(p_issue_numbers, ARRAY[]::BIGINT[]))
    AND t.status IS DISTINCT FROM 'completed';

  GET DIAGNOSTICS completed_tasks = ROW_COUNT;

  UPDATE webhook_events
  SET status = 'completed',
      error = NULL,
      processed_at = now()
  WHERE id = delivery.id
    AND claimed_at = p_claim_token;

  RETURN jsonb_build_object(
    'applied', true,
    'status', 'completed',
    'tickets_matched', matched_tickets,
    'tasks_completed', completed_tasks,
    'tasks_already_completed', already_completed
  );
END;
$$;

CREATE OR REPLACE FUNCTION fail_github_webhook_delivery(
  p_delivery_id TEXT,
  p_claim_token TIMESTAMPTZ,
  p_error TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  updated_count INT;
BEGIN
  UPDATE webhook_events
  SET status = 'failed',
      error = left(COALESCE(p_error, 'Webhook processing failed'), 500),
      processed_at = NULL
  WHERE delivery_id = trim(p_delivery_id)
    AND status = 'processing'
    AND claimed_at = p_claim_token;

  GET DIAGNOSTICS updated_count = ROW_COUNT;

  RETURN jsonb_build_object('updated', updated_count > 0);
END;
$$;

-- Supabase default privileges grant EXECUTE to postgres, anon, and authenticated
-- in addition to the PostgreSQL grant to PUBLIC. Strip every current EXECUTE
-- grantee except service_role, then fail if any other grant remains.
DO $$
DECLARE
  fn regprocedure;
  role_name text;
  leftover text;
BEGIN
  FOREACH fn IN ARRAY ARRAY[
    'public.claim_github_webhook_delivery(text, integer)'::regprocedure,
    'public.complete_github_webhook_delivery(text, timestamp with time zone, text, text, timestamp with time zone, bigint[])'::regprocedure,
    'public.fail_github_webhook_delivery(text, timestamp with time zone, text)'::regprocedure
  ]
  LOOP
    FOR role_name IN
      SELECT CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END
      FROM pg_proc p
      CROSS JOIN LATERAL aclexplode(
        COALESCE(p.proacl, acldefault('f'::"char", p.proowner))
      ) AS acl
      LEFT JOIN pg_roles r ON r.oid = acl.grantee
      WHERE p.oid = fn
        AND acl.privilege_type = 'EXECUTE'
        AND (acl.grantee = 0 OR r.rolname IS DISTINCT FROM 'service_role')
    LOOP
      IF role_name = 'PUBLIC' THEN
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', fn);
      ELSE
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM %I', fn, role_name);
      END IF;
    END LOOP;

    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO service_role', fn);

    SELECT string_agg(
      DISTINCT CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END,
      ', '
      ORDER BY CASE WHEN acl.grantee = 0 THEN 'PUBLIC' ELSE r.rolname END
    )
    INTO leftover
    FROM pg_proc p
    CROSS JOIN LATERAL aclexplode(p.proacl) AS acl
    LEFT JOIN pg_roles r ON r.oid = acl.grantee
    WHERE p.oid = fn
      AND acl.privilege_type = 'EXECUTE'
      AND (acl.grantee = 0 OR r.rolname IS DISTINCT FROM 'service_role');

    IF leftover IS NOT NULL THEN
      RAISE EXCEPTION
        'Function % still grants EXECUTE to %', fn, leftover;
    END IF;
  END LOOP;
END;
$$;
