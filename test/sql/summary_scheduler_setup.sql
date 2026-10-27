-- Minimal schema in a disposable database; no Supabase or external requests.
CREATE TABLE public.meetings (
    id UUID PRIMARY KEY,
    created_at TIMESTAMPTZ,
    final_transcription JSONB
);

CREATE SCHEMA net;
CREATE TABLE public.summary_requests (
    request_id BIGSERIAL PRIMARY KEY,
    meeting_id UUID NOT NULL,
    url TEXT NOT NULL,
    headers JSONB NOT NULL
);

-- Match pg_net's named parameters and bigint request ID result.
CREATE FUNCTION net.http_post(url TEXT, body JSONB, headers JSONB)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    new_request_id BIGINT;
BEGIN
    INSERT INTO public.summary_requests (meeting_id, url, headers)
    VALUES ((body->>'meeting_id')::UUID, url, headers)
    RETURNING request_id INTO new_request_id;
    RETURN new_request_id;
END;
$$;

CREATE SCHEMA cron;
CREATE TABLE cron.scheduled_jobs (name TEXT, schedule TEXT, command TEXT);
CREATE FUNCTION cron.schedule(name TEXT, schedule TEXT, command TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO cron.scheduled_jobs VALUES (name, schedule, command);
    RETURN 1;
END;
$$;

CREATE FUNCTION public.assert_summary(condition BOOLEAN, message TEXT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    IF condition IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION 'Summary scheduler regression: %', message;
    END IF;
END;
$$;
