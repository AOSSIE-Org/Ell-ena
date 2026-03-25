# Contributing to Ell-ena

This guide explains how to set up Ell-ena locally (frontend + Supabase backend) and how to contribute via pull requests.

## Prerequisites

1. **Flutter SDK**
   - The app is a Flutter project. `pubspec.yaml` targets Dart `>=2.17.0 <4.0.0`.
2. **Supabase development tooling**
   - **Node.js and npm** (required by the Supabase CLI workflow)
   - **Docker** (required for local development with Supabase CLI)
   - **Git**
3. **External service keys**
   - `GEMINI_API_KEY` (used by the app’s AI features)
   - `VEXA_API_KEY` (used by Supabase Edge Functions in `supabase/functions`)

## Local Setup

### 1. Clone the repository

```bash
git clone <repository-url>
cd Ell-ena
```

### 2. Install Flutter dependencies

```bash
flutter pub get
```

### 3. Configure environment variables (`.env`)

The Flutter app loads environment variables from a root `.env` file using `flutter_dotenv` during startup (see `lib/services/supabase_service.dart` and `lib/services/ai_service.dart`).

1. Copy the example file:
   - Copy `.env.example` to `.env` in the project root.
   - (Optional) On Windows PowerShell:
     - `Copy-Item .env.example .env`

2. Fill in the values in `.env`:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `GEMINI_API_KEY`
   - `VEXA_API_KEY`
   - `OAUTH_REDIRECT_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`

### 4. Set up the Supabase backend (migrations + Edge Functions)

The repository contains:
- SQL migration scripts under `supabase/migrations/`
- Edge Functions under `supabase/functions/`

1. Install and authenticate Supabase CLI (Supabase CLI setup is described in `BACKEND.md`).
2. Initialize and link the Supabase project:
```bash
supabase login
supabase init
supabase link --project-ref YOUR_PROJECT_REF
```

> Note: This repo does not include `supabase/config.toml` in git. Running `supabase init` will generate the config locally.

3. Deploy the database schema:
```bash
supabase db push
```

4. Deploy Edge Functions:
```bash
supabase functions deploy
```

5. Configure required Edge Function secrets in Supabase:
```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase secrets set SUPABASE_DB_URL=your-db-url
supabase secrets set GEMINI_API_KEY=your-gemini-api-key
supabase secrets set VEXA_API_KEY=your-vexa-api-key
```

### 5. (Optional) Run Edge Functions locally

If you want to serve Supabase Edge Functions locally while using your local `.env`:

```bash
supabase functions serve --allow-env --env-file .env
```

### 6. Run the Flutter app

With your `.env` configured and Supabase backend set up:

```bash
flutter run
```

To list devices first:

```bash
flutter devices
```

## Configuration

### Environment variables summary

- **Frontend (Flutter) reads from `.env`:**
  - `SUPABASE_URL`, `SUPABASE_ANON_KEY` (used to initialize Supabase client)
  - `GEMINI_API_KEY` (used by the app’s AI service)
  - `VEXA_API_KEY`, `OAUTH_REDIRECT_URL` (required by parts of the app and/or backend integrations)

- **Edge Functions require secrets set in Supabase:**
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `SUPABASE_DB_URL`
  - `GEMINI_API_KEY`
  - `VEXA_API_KEY`

## Development Workflow

### Branch naming

Follow the convention used in `README.md` examples:
- Create a feature branch like `feature/<name>` for new work.

### Commit messages

Use clear, descriptive commit messages. Align with the wording you’d use in the PR description.

### Running checks and tests

- Lint/analyzer:
```bash
flutter analyze
```

- Tests:
```bash
flutter test
```

## Pull Request Guidelines

1. Use a feature branch and open a PR against the main branch.
2. Include a clear description of what changed and why (see `.github/PULL_REQUEST_TEMPLATE.md`).
3. Add/adjust tests when behavior changes (if applicable).
4. Update documentation when needed.

### PR checklist (recommended)

- [ ] I have read the contributing guidelines.
- [ ] I have added tests that prove my fix is effective or that my feature works.
- [ ] I have added necessary documentation (if applicable).
- [ ] Any dependent changes have been merged and published in downstream modules.

## References

- `BACKEND.md` (Supabase CLI, secrets, migrations, Edge Functions)
- `FRONTEND.md` (Flutter setup and running the app)

