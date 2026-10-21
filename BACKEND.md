# Ell-ena Backend Setup Guide

This document provides a comprehensive guide to set up the Supabase backend for the Ell-ena project. Follow these steps to get your backend up and running quickly.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installing Supabase CLI](#installing-supabase-cli)
3. [Setting Up Supabase Project](#setting-up-supabase-project)
4. [Configuring Environment Variables](#configuring-environment-variables)
5. [Deploying Database Schema](#deploying-database-schema)
6. [Setting Up Authentication](#setting-up-authentication)
7. [Deploying Edge Functions](#deploying-edge-functions)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js and npm**: Download from [nodejs.org](https://nodejs.org/)
- **Docker**: Required for local development. Download [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- **Git**: To clone the repository

## Installing Supabase CLI

The Supabase CLI is essential for managing your Supabase projects locally and deploying to production.

### For Windows (using Scoop)

1. If you don't have Scoop installed, install it first:

   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   irm get.scoop.sh | iex
   ```

2. Add the Supabase bucket and install the CLI:

   ```powershell
   scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
   scoop install supabase
   ```

3. Verify the installation:
   ```powershell
   supabase --version
   ```

### For macOS (using Homebrew)

1. If you don't have Homebrew installed, install it first:

   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. Install the Supabase CLI:

   ```bash
   brew install supabase/tap/supabase
   ```

3. Verify the installation:
   ```bash
   supabase --version
   ```

### For Linux

```bash
npm install -g supabase
```

## Setting Up Supabase Project

### 1. Create a Supabase Account

1. Visit [app.supabase.com](https://app.supabase.com) and sign up for an account if you don't have one.
2. After signing up, you'll be directed to the dashboard.

### 2. Create a New Project

1. Click on "New Project" button.
2. Enter a name for your project (e.g., "Ell-ena").
3. Create a strong database password and store it securely.
4. Choose a region closest to your users.
5. Click "Create new project".

The project creation will take a few minutes. Once completed, you'll be redirected to the project dashboard.

### 3. Link Your Local Project to Supabase

1. Authenticate the CLI with your Supabase account:

   ```bash
   supabase login
   ```

   This will open a browser window where you need to authorize the CLI.

2. Navigate to your project directory:

   ```bash
   cd path/to/Ell-ena
   ```

3. Initialize Supabase in your project (if not already initialized):

   ```bash
   supabase init
   ```

4. Link your local project to the remote Supabase project:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   ```
   Replace `YOUR_PROJECT_REF` with your project reference ID found in the Supabase dashboard URL.

## Configuring Environment Variables

1. Copy the `.env.example` file to create a new `.env` file:

   ```bash
   cp .env.example .env
   ```

2. Get your Supabase credentials from the project dashboard:

   - Go to Settings > API in your Supabase dashboard
   - Copy the URL, anon key, and service role key

3. Update your `.env` file with these values:

   ```
   SUPABASE_URL=<YOUR_SUPABASE_URL>
   SUPABASE_ANON_KEY=<YOUR_SUPABASE_ANON_KEY>
   SUPABASE_SERVICE_ROLE_KEY=<YOUR_SUPABASE_SERVICE_ROLE_KEY>
   ```

4. For the GEMINI_API_KEY:

   - Visit [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create an API key and add it to your `.env` file

5. Obtain your VEXA_API_KEY:

   1. Go to [https://vexa.ai/](https://vexa.ai/).
   2. Click on the **"Get Started"** button.
   3. Login using your **Google account**.
   4. Once logged in, navigate to the API section to generate your **API key**.
   5. Copy the API key and paste it into the appropriate configuration file or environment variable in your project.

## Deploying Database Schema

The project includes SQL scripts in the `sqls` directory that define the database schema, tables, functions, and policies.

### 1. Deploy the Schema Using the CLI

Run the following commands in sequence to deploy all SQL scripts:

```bash
supabase db push
```

If you encounter any issues or prefer to run the scripts manually, you can execute them directly in the SQL editor:

### 2. Manual SQL Execution

1. Go to the SQL Editor in your Supabase dashboard.
2. Execute the SQL scripts in the following order:

   ```bash
   # User authentication and teams
   01_user_auth_schema.sql
   02_user_auth_policies.sql

   # Task management
   03_task_schema.sql

   # Ticket management
   04_tickets_schema.sql

   # Meetings and transcriptions
   05_meetings_schema.sql
   06_meeting_transcription.sql
   07_meetings_processed_transcriptions.sql
   08_meetings_ai_summary.sql
   09_meeting_vector_search.sql
   10_generate_missing_embeddings.sql
   11_task_ticket_description_embeddings.sql
   12_task_ticket_embedding_automation.sql
   13_hnsw_embedding_indexes.sql
   14_rag_search.sql
   15_rag_hybrid_ranking.sql
   16_rag_hybrid_weights_semantic_dominant.sql
   
   # GitHub integration
   17_github_integration_foundation.sql
   19_github_webhook_task_linking.sql
   ```

Each script creates specific tables, functions, or sets up row-level security policies.

## Setting Up Authentication

Supabase provides built-in authentication. The project uses email-based authentication with OTP (One-Time Password) codes and Google OAuth.

### 1. Configure Email Authentication Provider

1. Open your Supabase Dashboard → **Authentication** → **Providers** → **Email**
2. Ensure the following options are enabled:
   - ✅ Enable Email Signups
   - ✅ Enable Email Confirmations
   - ✅ Secure Email Change

### 2. Configure Google OAuth Provider

#### Step 1: Google Cloud Console Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Navigate to **APIs & Services** → **Credentials**

**For Android:**

1. Click **Create Credentials** → **OAuth client ID**
2. Application type: **Android**
3. Name: `Ell-ena Android`
4. Package name: `org.aossie.ell_ena`
5. Get SHA-1 certificate fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
6. Paste the SHA-1 fingerprint
7. Click **Create** and copy the Client ID

**For iOS:**

1. Click **Create Credentials** → **OAuth client ID**
2. Application type: **iOS**
3. Name: `Ell-ena iOS`
4. Bundle ID: `org.aossie.ellena` (from `ios/Runner.xcodeproj`)
5. Click **Create** and copy the Client ID

**For Web (Required by Supabase):**

1. Click **Create Credentials** → **OAuth client ID**
2. Application type: **Web application**
3. Name: `Ell-ena Web`
4. Authorized redirect URIs: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`
   - Replace `YOUR_PROJECT_REF` with your Supabase project reference
5. Click **Create** and copy both Client ID and Client Secret

**OAuth Consent Screen:**

1. Go to **OAuth consent screen**
2. User Type: **External**
3. Fill in required fields:
   - App name: **Ell-ena**
   - User support email: Your email
   - Developer contact: Your email
4. Save and continue

#### Step 2: Supabase Dashboard Configuration

1. Go to **Authentication** → **Providers** → **Google**
2. Toggle **Enable Sign in with Google** to ON
3. **Client ID (for OAuth)**: Paste Web Client ID
4. **Client Secret (for OAuth)**: Paste Web Client Secret
5. **Skip nonce check**: Toggle ON
6. Click **Save**

#### Step 3: Add Redirect URLs

1. Go to **Authentication** → **URL Configuration**
2. Under **Redirect URLs**, add:
   ```
   io.supabase.ellena://login-callback/
   ```
3. Click **Save**

### 3. Configure OTP Email Template

1. Go to **Authentication** → **Emails** in your Supabase project.
2. Under the **Magic Link** and **Confirm Signup** section, click **Edit Template**.
3. Replace the default content with the following HTML:

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8" />
    <title>Your Verification Code</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        background-color: #f4f6f8;
        margin: 0;
        padding: 40px;
      }
      .container {
        max-width: 480px;
        margin: auto;
        background-color: #ffffff;
        padding: 30px;
        border-radius: 10px;
        box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
        text-align: center;
      }
      .otp {
        font-size: 36px;
        font-weight: bold;
        letter-spacing: 8px;
        margin: 20px 0;
        color: #57ad03;
      }
      .message {
        font-size: 16px;
        color: #333333;
      }
      .footer {
        margin-top: 40px;
        font-size: 12px;
        color: #888888;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h2>Verify Your Email</h2>
      <p class="message">
        Use the 6-digit code below to verify your email address:
      </p>
      <div class="otp">{{ .Token }}</div>
      <p class="message">
        This code will expire in a few minutes. Please do not share it with anyone.
      </p>
      <div class="footer">&copy; Ellena App. All rights reserved.</div>
    </div>
  </body>
</html>
```

4. Click **Save** to update your email template.

### 3. Configure Additional Settings

1. Go to **Authentication** → **URL Configuration**.
2. Set the **Site URL** to your application's URL.
3. Add any additional redirect URLs if needed.

## Required Secrets

The project requires the following environment variables. **Do NOT expose server-only secrets in the client app**.

### Client-safe secrets (can be used in Flutter/mobile `.env`):

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

### Server-only secrets (set via Supabase CLI or `.env` in `supabase/functions/`, ignored by Git):

- `SUPABASE_SERVICE_ROLE_KEY`
- `SUPABASE_DB_URL`
- `GEMINI_API_KEY`
- `VEXA_API_KEY`
- `GITHUB_TOKEN` (server-only; used by Edge Functions for GitHub API access)
- `GITHUB_WEBHOOK_SECRET` (server-only; reserved for webhook signature verification)
- `EDGE_INTERNAL_SECRET` (if used for internal auth gating)

### Setting secrets via Supabase CLI

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase secrets set SUPABASE_DB_URL=your-db-url
supabase secrets set GEMINI_API_KEY=your-gemini-api-key
supabase secrets set VEXA_API_KEY=your-vexa-api-key
supabase secrets set GITHUB_TOKEN=your-github-token
supabase secrets set GITHUB_WEBHOOK_SECRET=your-webhook-secret
supabase secrets set EDGE_INTERNAL_SECRET=your-internal-secret


# Local Testing the functions (optional)
supabase functions serve --allow-env --env-file .env
```



## Deploying Edge Functions

The project uses Supabase Edge Functions for serverless functionality. Deploy them using the CLI:

```bash
# Deploy all functions
supabase functions deploy


# Or deploy specific functions
supabase functions deploy fetch-transcript
supabase functions deploy generate-embeddings
supabase functions deploy get-embedding
supabase functions deploy search-meetings
supabase functions deploy start-bot
supabase functions deploy summarize-transcription
```

## Troubleshooting

### Common Issues and Solutions

1. **CLI Authentication Issues**

   - Run `supabase login` again to refresh your authentication.

2. **Database Migration Errors**

   - Check for syntax errors in your SQL files.
   - Ensure you're running migrations in the correct order.

3. **Edge Function Deployment Failures**

   - Verify that your function code is valid.
   - Check for any missing dependencies.
   - Ensure your Supabase project has the necessary permissions.

4. **Connection Issues**
   - Verify your environment variables are correctly set.
   - Check if your IP is allowed in the Supabase dashboard.

### Getting Help

If you encounter issues not covered in this guide:

->>> Join the conversation on the AOSSIE Ell-ena Discord channel!

1. Check the [Supabase Documentation](https://supabase.com/docs)
2. Visit the [Supabase GitHub Repository](https://github.com/supabase/supabase)
3. Join the [Supabase Discord Community](https://discord.supabase.com)

## Next Steps

After setting up your backend:

1. Connect your frontend application using the Supabase client.
2. Set up continuous integration for automated deployments.
3. Configure monitoring and alerts for your production environment.

---

This guide should help you get started with the Ell-ena backend.

## GitHub webhook

When a pull request is merged, GitHub sends a webhook to the `github-webhook` Edge Function. The function first checks that the request was really sent by GitHub. It does this by comparing the `X-Hub-Signature-256` header with a signature it calculates from the raw body and `GITHUB_WEBHOOK_SECRET`. Only after that check passes does it use the service-role key to update the database.

A task can optionally point at one ticket through `ticket_id`. One ticket can have several tasks. The task and the ticket must belong to the same team; the database rejects the link if they do not. A task with no ticket is left alone when a webhook arrives.

The pull request description must mention the GitHub issue with `Closes`, `Fixes`, or `Resolves`, for example `Fixes #123`. Ell-ena finds the ticket only when the issue number and the repository both match: `tickets.gh_issue_id`, `tickets.gh_repo`, and the server setting `GITHUB_REPO`. It then marks the linked tasks completed, and saves the pull request URL in `gh_pr_url` and the merge time in `completed_at`. Tasks that were already completed keep the completion details they already have.

### Secrets

```bash
supabase secrets set GITHUB_WEBHOOK_SECRET=your-webhook-secret
supabase secrets set GITHUB_REPO=owner/repository
supabase secrets set GITHUB_TOKEN=your-github-token
```

`GITHUB_WEBHOOK_SECRET`, `GITHUB_TOKEN`, and the service-role key stay on the server.

### Deploy

JWT verification is disabled for this function only, because GitHub does not send a Supabase user JWT. The HMAC check is still required.

```bash
supabase functions deploy github-webhook --no-verify-jwt
```

### GitHub configuration

In the repository settings, add a webhook:

- Payload URL: `https://<project-ref>.supabase.co/functions/v1/github-webhook`
- Content type: `application/json`
- Secret: the same value as `GITHUB_WEBHOOK_SECRET`
- Events: **Pull requests** only
- SSL verification: enabled

### Manual test

1. Create a ticket with **Create GitHub issue** and confirm `gh_issue_id` and `gh_repo` are set.
2. Create a task and choose that ticket. Leave a second task unlinked.
3. Open a pull request whose body contains `Fixes #<issue number>` and merge it.
4. Confirm the linked task is `completed`, `gh_pr_url` is the pull request URL, and `completed_at` matches the merge time.
5. Confirm the unlinked task is unchanged.
6. Redeliver the same webhook. The linked task's completion fields stay as they were.

### Limits

- Only the single repository in `GITHUB_REPO` is accepted.
- Issue references without `Closes`, `Fixes`, or `Resolves` are ignored.
- A qualified reference to another repository does not match.
- There is no GitHub OAuth or per-user GitHub account.
- The webhook does not edit GitHub issues or create tasks.

