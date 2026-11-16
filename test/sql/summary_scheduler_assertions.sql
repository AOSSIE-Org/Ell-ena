-- NOW() is fixed for the transaction, so the one-day boundary is exact.
INSERT INTO public.meetings
    (id, created_at, final_transcription, meeting_summary_json)
VALUES
    ('00000000-0000-0000-0000-000000000001', NOW() - INTERVAL '2 days', '[{"text":"Ready now"}]', NULL),
    ('00000000-0000-0000-0000-000000000002', NOW() - INTERVAL '7 days', '[]', NULL),
    ('00000000-0000-0000-0000-000000000003', NOW() - INTERVAL '1 day 1 microsecond', '[]', NULL),
    ('00000000-0000-0000-0000-000000000004', NOW() - INTERVAL '1 day', '[]', NULL),
    ('00000000-0000-0000-0000-000000000005', NOW() - INTERVAL '1 day' + INTERVAL '1 microsecond', '[]', NULL),
    ('00000000-0000-0000-0000-000000000006', NOW(), '[]', NULL),
    ('00000000-0000-0000-0000-000000000007', NULL, '[]', NULL),
    ('00000000-0000-0000-0000-000000000008', NOW() - INTERVAL '2 days', '[]', '{}'),
    ('00000000-0000-0000-0000-000000000009', NOW(), '[]', '{}'),
    ('00000000-0000-0000-0000-000000000010', NOW() - INTERVAL '2 days', NULL, NULL),
    ('00000000-0000-0000-0000-000000000011', NOW(), NULL, NULL);

SET LOCAL TIME ZONE 'UTC';
SELECT public.process_unsummarized_meetings();
SELECT public.assert_summary(
    (SELECT array_agg(meeting_id ORDER BY request_id) FROM public.summary_requests) = ARRAY[
        '00000000-0000-0000-0000-000000000002',
        '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000003',
        '00000000-0000-0000-0000-000000000004',
        '00000000-0000-0000-0000-000000000005',
        '00000000-0000-0000-0000-000000000006',
        '00000000-0000-0000-0000-000000000007'
    ]::UUID[],
    'old, boundary, recent and undated pending meetings must be dispatched; summarized and transcript-less rows must be skipped'
);

-- Pending requests remain eligible on a later run, irrespective of timezone.
TRUNCATE public.summary_requests;
SET LOCAL TIME ZONE 'Asia/Kolkata';
SELECT public.process_unsummarized_meetings();
SELECT public.assert_summary(
    (SELECT count(*) = 7 AND count(DISTINCT meeting_id) = 7
     AND bool_and(meeting_id < '00000000-0000-0000-0000-000000000008'::UUID)
     FROM public.summary_requests),
    'changing the session timezone must not change eligibility or prevent retries'
);

-- A transcript arriving after booking makes an old record eligible next run.
UPDATE public.meetings SET meeting_summary_json = '{}'
WHERE id < '00000000-0000-0000-0000-000000000008'::UUID;
UPDATE public.meetings SET final_transcription = '[{"text":"Late transcript"}]'
WHERE id = '00000000-0000-0000-0000-000000000010';
TRUNCATE public.summary_requests;
SELECT public.process_unsummarized_meetings();
SELECT public.assert_summary(
    (SELECT array_agg(meeting_id) FROM public.summary_requests) =
        ARRAY['00000000-0000-0000-0000-000000000010']::UUID[],
    'a newly ready old meeting must be processed and completed meetings must not be resubmitted'
);

-- More than one batch, with equal timestamps and reverse insertion order.
TRUNCATE public.meetings, public.summary_requests;
INSERT INTO public.meetings (id, created_at, final_transcription)
SELECT ('00000000-0000-0000-0000-' || lpad(n::TEXT, 12, '0'))::UUID,
       NOW() - INTERVAL '3 days', '[]'::JSONB
FROM generate_series(55, 1, -1) AS n;
SELECT public.process_unsummarized_meetings();
SELECT public.assert_summary(
    (SELECT array_agg(meeting_id ORDER BY request_id) FROM public.summary_requests) =
    (SELECT array_agg(('00000000-0000-0000-0000-' || lpad(n::TEXT, 12, '0'))::UUID ORDER BY n)
     FROM generate_series(1, 50) AS n),
    'each run must dispatch at most 50 meetings, with deterministic ordering for tied timestamps'
);

-- Simulate the Edge Function finishing the first batch.
UPDATE public.meetings SET meeting_summary_json = '{}'
WHERE id IN (SELECT meeting_id FROM public.summary_requests);
TRUNCATE public.summary_requests;
SELECT public.process_unsummarized_meetings();
SELECT public.assert_summary(
    (SELECT array_agg(meeting_id ORDER BY request_id) FROM public.summary_requests) =
    (SELECT array_agg(('00000000-0000-0000-0000-' || lpad(n::TEXT, 12, '0'))::UUID ORDER BY n)
     FROM generate_series(51, 55) AS n),
    'remaining old meetings must be processed on the next run'
);

UPDATE public.meetings SET meeting_summary_json = '{}';
TRUNCATE public.summary_requests;
SELECT public.process_unsummarized_meetings();
SELECT public.assert_summary(
    (SELECT count(*) = 0 FROM public.summary_requests),
    'an empty pending queue must not issue requests'
);
