# Summary scheduler regression tests

Run against an **empty, disposable PostgreSQL database** (PostgreSQL 16+):

```sh
psql "$TEST_DATABASE_URL" -X -v ON_ERROR_STOP=1 -f test/sql/summary_scheduler_test.sql
```

The tests call the actual scheduler after applying the historical migration and
its upgrade, then separately test the SQL mirror. Minimal meeting fixtures and
local `net.http_post` / `cron.schedule` stubs replace Supabase services. No HTTP
requests are sent. Each scenario rolls back its tables, schemas and functions.

Coverage includes late transcripts on old bookings, both sides of the exact
one-day boundary, already summarized/missing-transcript exclusions, timezone
independence, retries, deterministic 50-row batches, subsequent backlog drainage,
an empty queue, and preservation of configured HTTP settings and the cron job.

The upgrade changes only the original age-filter clause because deployments
configure the endpoint and authorization inside the function. If that clause
has been customized, the migration stops with an explicit error so its selection
logic can be reviewed instead of overwriting the deployed function. The original
historical migration remains unchanged.

The scheduler retains its existing retry behavior: pending rows are retried until
the Edge Function writes a summary. A permanently failing oldest batch requires
operator attention; retry tracking and dead-letter handling are separate work.
