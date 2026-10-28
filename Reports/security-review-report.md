# Security Review Report

- **Reviewing agent / model:** Claude Opus 5.5 (`claude-opus-5-5`), running in Claude Code
- **Reasoning effort / tier:** not disclosed by the runtime
- **Review date and time:** 2026-10-21T21:47:00Z

## Scope

Diff scope: the `security` branch compared with its base branch `main` (`git diff main...HEAD`), 251 files changed. Only vulnerabilities introduced or made worse by this diff are reported. Reviewed commit: `8cae3dad39a02a414f8bdc8dbe46520f77d3edcb`.

Detected project types:

- **Mobile app (Flutter):** `pubspec.yaml`, `lib/`, `android/`, `ios/`. The Flutter checklist was applied.
- **Flutter web build:** `web/index.html`, `web/support_us.js`, and JS interop in `lib/widgets/*_web.dart`. The browser-relevant frontend checklist items were applied (XSS, open redirect, CORS, secrets shipped to the client).
- **Supabase backend:**
  - Deno/TypeScript Edge Functions in `supabase/functions/`.
  - PostgreSQL migrations in `supabase/migrations/`, mirrored in `sqls/`.

  The skill's project-type table has no row for this stack, so the general checklist was applied, plus the authorization and injection items from the backend checklists.

Areas reviewed in detail:

- **Edge Functions:**
  - `github-webhook`: `index.ts`, `signature.ts`, `handler.ts`, `delivery.ts`, `pull_request.ts`
  - `github-sync`: `index.ts`, `sync_ticket.ts`
  - `_shared/github.ts`, `_shared/cors.ts`
  - `fetch-transcript`, `start-bot`, `summarize-transcription`, `generate-embeddings`, `get-embedding`
- **Migrations:**
  - RLS, `SECURITY DEFINER` functions, grants and revokes in `20260928120000_github_webhook_task_linking.sql`
  - The RAG search RPCs
  - The embedding automation triggers and cron jobs
  - The GitHub integration tables
- **Flutter:**
  - `lib/services/supabase_service.dart` and `lib/services/ai_service.dart`
  - Redirect handling in `lib/router/app_router.dart` and `lib/router/app_routes.dart`
  - `lib/screens/auth/`
- **Web:** `web/index.html`, `web/support_us.js`, `lib/widgets/social_share_host_web.dart`, `lib/widgets/support_us_host_web.dart`
- **CI:** `.github/workflows/tests.yml`

## Findings

No vulnerabilities introduced by this diff met the 0.7 confidence threshold.

The new trust boundaries were checked:

- **GitHub webhook signature check.** HMAC-SHA256 over the raw body, verified before parsing and before the service-role client is created. Length mismatches fail closed, the comparison is constant-time, and a missing secret or header is rejected.
- **`SECURITY DEFINER` functions.** They pin `search_path = public`. `EXECUTE` is revoked from `PUBLIC`, `anon` and `authenticated` and granted only to `service_role`, and the migration asserts this.
- **New `webhook_events` table.** RLS is enabled and there are no client policies.
- **RAG RPCs.** They run with invoker rights, so team-scoped RLS still applies.
- **Cross-team task–ticket links.** A trigger blocks linking a task to a ticket from another team.
- **`from` redirect parameter.** It is validated against an allow-list and rejects any scheme or host.
- **Flutter client.** It uses only the user session, never the service-role key.
- **Web scripts.** They contain static content only, and no untrusted data reaches a DOM sink.
- **CI workflow.** It uses `pull_request`, not `pull_request_target`. It doesn't interpolate `github.event` data and has no secrets.

These candidates were considered and scored below the threshold:

- **`github-sync` has no caller or team check before its service-role read and write** (`supabase/functions/github-sync/index.ts:105-114`). Exploiting it needs another team's ticket UUID, which RLS stops other teams from reading. It only acts on tickets whose owners already set `sync_to_github = true`, and the attacker can't choose the content that gets pushed.
- **`generate-embeddings` now accepts task and ticket IDs with no caller check** (`supabase/functions/generate-embeddings/index.ts:99-125`). It only recomputes an embedding from existing data and returns `{ success: true }`, with no data in the response.
- **CORS `Access-Control-Allow-Origin: *` in `supabase/functions/_shared/cors.ts`.** The functions authenticate with a bearer token in the `Authorization` header, not cookies. Browsers don't attach that header cross-origin automatically, so a wildcard origin doesn't enable cross-site requests made with a victim's credentials.

## Notes

No notes for this review.

## Limitations

**Standing limitations**

- This review does not replace a full manual audit or a penetration test.
- This is static analysis of source text. Nothing was executed, fuzzed, or traced at runtime, so timing-dependent, load-dependent, or infrastructure-dependent issues cannot be confirmed here.
- Confidence scores are the reviewing model's own self-assessment, not a calibrated statistical probability.
- Absence of a reported finding does not mean the code is secure. Safety guardrails built into some models can cause a real vulnerability to be softened, generalized, or left out rather than reported in exploit-level detail, and training-data bias can make some vulnerability classes easier for a model to recognize than others. Treat this report as a floor on what a full audit would find, not a ceiling.
- Findings reflect the reviewing model's training data cutoff. A vulnerability tied to a very recently disclosed CVE or library advisory may not be recognized as such.

**Review-specific limitations**

- **Size of the diff.** It is about 42,000 added lines.
  - The roughly 15,000 lines of tests under `test/` and `integration_test/` were excluded, as the skill requires.
  - Documentation, brand assets and images were not reviewed.
  - The Flutter UI screens under `lib/screens/` (other than `auth/`) and `lib/widgets/` were checked with targeted searches (logging of secrets, local storage, URL launching, redirects, DOM and JS interop) rather than read line by line.
- **Missing deployment config.** `supabase/config.toml` is not committed, so the per-function `verify_jwt` settings could not be confirmed. The review assumed the Supabase default (JWT verification on) for every function except `github-webhook`, which its own deploy instructions deploy with `--no-verify-jwt`.
- **Live database state.** It was not available. The repository versions of `queue_embedding` and the embedding cron functions contain placeholder URLs and keys, so the values patched into the live database were not reviewed.
- **Third-party scripts.** `web/index.html` loads scripts from jsDelivr and unpkg: `support-us-button@2.2.1`, React 18.3.1 and `AOSSIE-Org/SocialShareButton@v1.0.4`. Only the SocialShareButton source was checked, for how it handles the page URL. The other packages' source was not reviewed.
- **Pre-existing issues.** Issues that already exist on `main` and that this diff does not introduce or make worse are outside diff scope and are not reported here.
- No exploit-level detail was withheld from this report because of a content restriction.
