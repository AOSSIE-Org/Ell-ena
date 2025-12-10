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

1. Allow scripts to run
```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
2. Install Scoop if not installed
```powershell
   irm get.scoop.sh | iex
   ```
3. Add the Supabase bucket 
```powershell
   scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
   ```

4. Install Supabase CLI
```powershell
   scoop install supabase
   ```

5. Verify the installation:
   ```powershell
   supabase --version
   ```

### For macOS (using Homebrew)

1. Install Homebrew (if not installed)
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
supabase --version
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
   This opens a browser for authorization, Once authorized, your CLI is ready to link projects.

2. Navigate to your project directory:
   ```bash
   cd path/to/Ell-ena
   ```
   Replace path/to/Ell-ena with the actual path to your project folder.

3. Initialize Supabase in your project (if not already initialized):
   ```bash
   supabase init
   ```
   This creates a .supabase folder in your project directory.
   Important: If .supabase already exists, skip this step to avoid error.

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
   This copies the example environment variables to a new file you can safely edit.

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
   ```

Each script creates specific tables, functions, or sets up row-level security policies.

## Setting Up Authentication

Supabase provides built-in authentication. The project uses email-based authentication with OTP (One-Time Password) codes.

### 1. Configure Email Authentication Provider

1. Open your Supabase Dashboard → **Authentication** → **Providers** → **Email**
2. Ensure the following options are enabled:
   * ✅ Enable Email Signups
   * ✅ Enable Email Confirmations
   * ✅ Secure Email Change
### 2. Configure OTP Email Template

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
      <div class="footer">
        &copy; Ellena App. All rights reserved.
      </div>
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
- `EDGE_INTERNAL_SECRET` (if used for internal auth gating)

### Setting secrets via Supabase CLI

```bash
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase secrets set SUPABASE_DB_URL=your-db-url
supabase secrets set GEMINI_API_KEY=your-gemini-api-key
supabase secrets set VEXA_API_KEY=your-vexa-api-key
supabase secrets set EDGE_INTERNAL_SECRET=your-internal-secret
 ```
 
### Function Descriptions

- **fetch-transcript**: Retrieves meeting transcriptions
- **generate-embeddings**: Creates vector embeddings for meeting content
- **get-embedding**: Retrieves embeddings for specific content
- **search-meetings**: Performs semantic search across meeting transcriptions
- **start-bot**: Initializes the AI assistant
- **summarize-transcription**: Generates AI summaries of meeting transcriptions

## Deploying Edge Functions

   Supabase Edge Functions enable serverless functionality. Deploy them using the CLI.

### Deploy All Functions
```bash
   supabase functions deploy
   ```
```bash
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