# AGENTS.md

Instructions for agents working in this repo.

## Stack

- Flutter / Dart (`>=2.17.0 <4.0.0`, Flutter 3.7.0+)
- Riverpod + Freezed; `provider` for `ThemeController`
- Supabase (PostgreSQL + `vector`)
- Gemini chat in `AIService` (`gemini-2.5-flash`)
- Gemini embeddings in Edge Function `get-embedding`
- Vexa meeting bots via `start-bot` and `fetch-transcript`
- Root `.env` loaded by `flutter_dotenv` (copy `.env.example`; gitignored)

## Commands

```bash
flutter pub get
flutter run
flutter run -d <device-id>
dart format .
flutter analyze
flutter test
flutter test test/widget_test.dart
flutter build apk --release
flutter build ios --release
```

Dashboard codegen (`lib/providers/dashboard/`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Supabase (`config.toml` is not committed):

```bash
supabase login
supabase init
supabase link --project-ref <project-ref>
supabase db push
supabase functions deploy
supabase functions serve --allow-env --env-file .env
```

Fully restart the app after changing `.env`.

## Layout

| Path | Role |
|---|---|
| `lib/screens/` | UI (mostly `StatefulWidget`) |
| `lib/services/` | `SupabaseService`, `AIService`, `MeetingFormatter` |
| `lib/providers/` | Riverpod |
| `lib/widgets/`, `lib/theme/`, `lib/core/responsive/` | Shared UI |
| `supabase/migrations/` | Schema source of truth |
| `sqls/` | Dev SQL mirror — do not deploy from here |
| `supabase/functions/` | Edge Functions |
| `test/` | `flutter_test` |

No `lib/repositories/` layer. Do not add one unless asked.

```
ChatScreen / other screens
  → SupabaseService    # auth + CRUD, user JWT, RLS
  → AIService          # Gemini + meeting retrieval
  → supabase/functions/
```

**Chat** keeps `_messages` and `_isProcessing` in `ChatScreen`.

**Meeting retrieval:** `_isMeetingRelatedQuery` → `queue_embedding` → `search_meeting_summaries_by_resp_id` → `MeetingFormatter` → Gemini, plus tools, date, team roster, and history.

**Transcription:** `start-bot` → stored transcript → `summarize-transcription`.

Edge Functions present: `fetch-transcript`, `generate-embeddings`, `get-embedding`, `start-bot`, `summarize-transcription`, `_shared/cors.ts`. `search-meetings` is not in the tree.

## Riverpod

`ProviderScope` is in `lib/main.dart`.

- `themeControllerProvider` — `ChangeNotifierProvider`, overridden at startup
- `dashboardControllerProvider` — `@Riverpod(keepAlive: true)` + Freezed; commit generated files
- `homeTabIndexProvider` — `StateProvider<int>`, not wired to `HomeScreen`

Reuse these. Do not add a second theme or dashboard store. Do not move chat onto Riverpod unless asked.

## Database

- New schema = new timestamped migration in `supabase/migrations/`
- Tasks, tickets, meetings, users, and teams use team-scoped RLS
- Flutter uses the user session in `SupabaseService`, never the service-role key
- Reuse RPCs in `20251021090000_meeting_vector_search.sql`: `queue_embedding`, `get_embedding_response`, `extract_embedding`, `get_similar_meetings`, `search_meeting_summaries_by_resp_id`
- `queue_embedding` in git has placeholders. Patch the live DB only; do not commit real URLs or keys

Edge secrets: `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_DB_URL`, `GEMINI_API_KEY`, `VEXA_API_KEY`

Client `.env`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, plus the other keys in `.env.example`

## AI

- Gemini stays in `AIService`
- Formatting stays in `MeetingFormatter`
- Chat UI stays in `ChatScreen`
- Embeddings go through `queue_embedding` / `get-embedding`, not Flutter → Gemini
- Keep system prompt, tools, date, team list, and history
- Do not dump all tasks, tickets, or meetings into the prompt
- Do not change the model unless asked

## Tests

Only `test/widget_test.dart` exists today.

```bash
flutter test
```

Add tests next to new logic. Do not pump `MyApp` unless `.env` and Supabase are available.

## Security

- Never commit `.env`, API keys, or service-role JWTs
- Never put `SUPABASE_SERVICE_ROLE_KEY` in Flutter
- Never bypass RLS or weaken auth to ship a feature
- Never hardcode URLs or keys

## Git

```bash
git checkout -b feat/<short-description>   # also fix/, docs/, refactor/
```

One feature per PR. Link `Closes #<n>`. Clear commit messages. Run `flutter analyze` and `flutter test` before opening.

## Do not

- Change schema without a migration
- Bypass RLS
- Duplicate meeting-search RPCs
- Commit secrets into SQL
- Swap Vexa or Gemini unless asked
- Refactor unrelated code in a scoped change
