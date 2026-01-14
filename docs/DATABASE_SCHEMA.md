# Supabase Database Schema

This document describes the tables, columns, and relationships used by the application database.

## 📌 High-Level Schema Overview

The database is organized around teams and collaboration features.

- A **team** can have many **users**
- Users can create:
  - **tasks**
  - **tickets**
  - **meetings**
- Tasks and tickets may have **comments**
- Meetings can produce:
  - transcriptions
  - AI summaries
  - embeddings used for semantic search

Most tables link through:

- `team_id` → teams
- `created_by` / `assigned_to` → auth.users / users

###  Schema Relationship Map

Teams ──< Users
Teams ──< Tasks ──< Task Comments
Teams ──< Tickets ──< Ticket Comments
Teams ──< Meetings → Transcription → Summary → Embeddings

---

## Global Security Model (RLS Overview)

Row Level Security (RLS) is enabled across core tables.

Access is primarily restricted based on:

- team membership
- creator / assignee identity
- admin role for privileged actions

Each table defines its **own RLS policies** (documented in its section below).

A helper view `user_teams` is used to check team membership:

| Column | Description |
|------|-------------|
| id | User ID (`users.id`) |
| team_id | Team the user belongs to |

---

## Table: teams

Purpose: Stores information about teams / workspaces in the application.

| Column | Type | Description |
|------|------|-------------|
| id | uuid | Primary key (auto-generated) |
| name | text | Team name |
| team_code | text | Unique 6-character team invite/join code |
| created_at | timestamptz | Time when team was created |
| created_by | uuid | ID of the user who created the team |
| admin_name | text | Name of the team admin |
| admin_email | text | Email address of the team admin |

**Rules & Behavior**

- `team_code` must be exactly 6 characters
- RLS is enabled
- Team members can view only **their own team**
- Only the creator/admin can update the team

**Relationships**

- A team can have many **users**
- Tasks, tickets, and meetings reference `teams.id`

---

## Table: users

Purpose: Application user profile table (linked to Supabase `auth.users`).

| Column | Type | Description |
|------|------|-------------|
| id | uuid | Primary key — references `auth.users.id` |
| full_name | text | User’s full name |
| email | text | Unique email address |
| team_id | uuid | Team the user belongs to (`teams.id`) |
| role | text | `admin` or `member` |
| google_refresh_token | text | OAuth token (optional) |
| created_at | timestamptz | Profile creation time |
| updated_at | timestamptz | Last profile update time |

**Rules & Behavior**

- Users can view **only members of their own team**
- Users can update **only their own profile**
- Inserts allowed only for authenticated users

**Relationships**

- Each user belongs to **one team**
- Tasks & tickets reference users as:
  - `created_by`
  - `assigned_to`

---

## Table: tasks

Purpose: Stores task information for team members.

| Column | Type | Description |
|------|------|-------------|
| id | uuid | Primary key |
| title | text | Task title |
| description | text | Task details (optional) |
| status | text | `todo`, `in_progress`, `completed` |
| approval_status | text | `pending`, `approved`, `rejected` |
| created_at | timestamptz | Time created |
| updated_at | timestamptz | Time last updated |
| due_date | timestamptz | Optional deadline |
| team_id | uuid | References `teams.id` |
| created_by | uuid | Creator (`auth.users.id`) |
| assigned_to | uuid | Assignee (`auth.users.id`) |

**Relationships**

- Belongs to one **team**
- Created by a **user**
- May be assigned to a **user**

**Notes**

- RLS enabled
- Team members can create & view tasks in their team
- Creator / assignee / admin may update
- `updated_at` auto-updates via trigger

---

## Table: task_comments

Purpose: Stores comments on tasks.

| Column | Type | Description |
|------|------|-------------|
| id | uuid | Primary key |
| task_id | uuid | References `tasks.id` |
| user_id | uuid | Comment author |
| content | text | Comment text |
| created_at | timestamptz | Time created |

**Behavior / Rules**

- Deleted task → deletes comments
- Users may:
  - view comments for tasks in their team
  - add comments to tasks in their team
  - edit/delete **their own comments**

---

## Table: tickets

Purpose: Tracks issue / request tickets within a team.

| Column | Type | Description |
|------|------|-------------|
| id | uuid | Primary key |
| ticket_number | text | Auto-generated code (TEAM-001) |
| title | text | Ticket title |
| description | text | Details |
| priority | text | `low`, `medium`, `high` |
| category | text | Ticket category |
| status | text | `open`, `in_progress`, `resolved` |
| approval_status | text | `pending`, `approved`, `rejected` |
| created_by | uuid | Creator |
| assigned_to | uuid | Assignee |
| team_id | uuid | Team |
| created_at | timestamptz | Time created |
| updated_at | timestamptz | Time updated |

**Behavior**

- Ticket numbers auto-generated by team prefix
- `updated_at` auto-updates

**RLS**

- Team members can view tickets in their team
- Creator / assignee / admins may update

---

##  Table: ticket_comments

Purpose: Stores comments on tickets.

| Column | Type | Description |
|------|------|-------------|
| id | uuid | Primary key |
| ticket_id | uuid | References `tickets.id` |
| user_id | uuid | Comment author |
| content | text | Comment text |
| created_at | timestamptz | Time created |

**Behavior**

- Deleted ticket → deletes comments
- Users may:
  - view comments in their team
  - create comments in their team
  - edit/delete **their own comments**

---

##  Table: meetings

Purpose: Stores meetings and AI-processing data.

| Column | Type | Description |
|------|------|-------------|
| id | uuid | Primary key |
| meeting_number | text | Auto code (MTG-001, …) |
| title | text | Meeting title |
| description | text | Optional description |
| meeting_date | timestamptz | Scheduled time |
| meeting_url | text | Meeting link |
| transcription | text | Raw transcription |
| ai_summary | text | AI summary (legacy) |
| duration_minutes | int | Expected duration |
| bot_started_at | timestamptz | Bot start time |
| transcription_attempted_at | timestamptz | Transcript attempt time |
| transcription_error | text | Error log |
| created_by | uuid | Creator |
| team_id | uuid | Team |
| created_at | timestamptz | Created time |
| updated_at | timestamptz | Last update |
| final_transcription | jsonb | Cleaned transcript |
| meeting_summary_json | jsonb | AI summary JSON |
| summary_embedding | vector(768) | Embedding for search |

**Access Rules**

- Team members may view meetings in their team
- Creator or admins may update/delete

**Automation**

- Bot runs near meeting time
- Transcript fetched after meeting ends
- Errors stored in `transcription_error`
- Old meetings may be auto-cleaned

---

## Final Transcription Processing (Meetings)

`final_transcription` stores cleaned segments:

```json
[
  { "speaker": "User 1", "text": "Hello everyone" },
  { "speaker": "User 2", "text": "Let's start the meeting" }
]
```

##  Automation & Background Jobs (Meetings Bot)

The database includes functions and scheduled jobs that automate the
meeting transcription workflow.

###  Function: start_meeting_bot()

Purpose: Starts the transcription bot when a meeting is about to begin.

Behavior:
- Runs every minute (via pg_cron)
- Finds meetings starting within ±5 minutes
- Only runs for Google Meet URLs
- Triggers the `/start-bot` Supabase Edge Function
- Marks `bot_started_at` when triggered

---

###  Function: fetch_meeting_transcript()

Purpose: Fetches the meeting transcript after the meeting ends.

Behavior:
- Runs every minute (via pg_cron)
- Waits until `duration_minutes` after meeting time
- Only runs if:
  - bot was started
  - transcript not yet attempted
- Calls `/fetch-transcript` Supabase Edge Function
- Updates `transcription_attempted_at`

---

###  Scheduled Jobs (pg_cron)

| Job | Schedule | Action |
|------|---------|--------|
| `start-bot` | Every 1 minute | Runs `start_meeting_bot()` |
| `fetch-transcript` | Every 1 minute | Runs `fetch_meeting_transcript()` |

These jobs automate:
- starting the transcription bot
- fetching the transcript after the meeting


###  AI Meeting Summary Processing

The `meetings` table includes an additional field for storing AI-generated
summaries of meeting transcriptions.

| Column | Type | Description |
|------|------|-------------|
| meeting_summary_json | jsonb | AI-generated structured summary for the meeting |

**Purpose**
- Once `final_transcription` is available, the system automatically requests an
  AI summary for that meeting.
- The summary is produced by a Supabase Edge Function
  (`summarize-transcription`) and stored in this column.

**Automation Job**
- Function: `process_unsummarized_meetings()`
- Runs every minute (via pg_cron)
- Processes meetings where:
  - `final_transcription` is not null
  - `meeting_summary_json` is null
  - meeting was created in the last 24 hours

The function:
- sends an HTTP request with the meeting ID
- calls the `summarize-transcription` Edge Function
- summary is saved into `meeting_summary_json`

##  AI Embeddings & Semantic Search (Meetings)

The database supports semantic search across meeting summaries using AI
embeddings and the PostgreSQL `vector` extension.

###  Embedding Workflow (High Level)

1. Text is sent to the `/get-embedding` Edge Function  
2. The API returns an embedding vector (size 768)
3. The embedding is compared with stored meeting embeddings
4. The system returns the most similar meetings

---

### Function: `queue_embedding(text)`

Sends text to the embedding API and returns a response ID.

Used when:
- A search query needs to be converted to an embedding

---

### Function: `get_embedding_response(resp_id)`

Waits for the async embedding API response.

Behavior:
- Polls `net._http_response` until a response is available
- Fails if no response arrives within the timeout window

---

### Function: `extract_embedding(api_response)`

Extracts and converts the embedding:

- Reads the `embedding` field from the API JSON payload
- Converts it to `vector(768)`

---

### Function: `get_similar_meetings(query_embedding)`

Returns the most similar meetings based on embeddings.

Result columns:

| Field | Description |
|------|-------------|
| meeting_id | Matching meeting ID |
| title | Meeting title |
| meeting_date | Meeting date |
| similarity | Similarity score (higher = closer match) |
| summary | Meeting summary JSON |

Similarity is computed using:

- `m.summary_embedding <=> query_embedding`

---

###  Function: `search_meeting_summaries_by_resp_id(resp_id)`

Full end-to-end semantic search helper.

Steps:
1. Wait for embedding response
2. Extract vector
3. Call `get_similar_meetings()`
4. Return top matching meetings

Used for:
- "Search meetings by meaning"
- AI search across summaries

---

###  Embedding Backfill & Maintenance

Some meetings may already have AI summaries but do not yet have an embedding
stored for semantic search.

To fix this gap, the system includes an automated backfill job.

| Function | Purpose |
|--------|--------|
| `process_meetings_missing_embeddings()` | Generates embeddings for meetings missing `summary_embedding` |

**Behavior**

- Processes meetings where:
  - `meeting_summary_json` is not null
  - `summary_embedding` is null
  - the meeting was created within the last 30 days

- For each matching meeting:
  - Calls the `/generate-embeddings` Edge Function
  - stores the generated embedding for future search
  - Runs on a recurring schedule via `pg_cron`

This ensures older meetings are still included in semantic search results.
