# Ell-ena Database Schema Guide

This document provides a comprehensive overview of the **database schema** used by the Ell-ena application. It explains the tables, relationships, and SQL required to deploy the schema using Supabase.

The schema is designed to support team-based collaboration, task and ticket management, and AI-assisted meeting workflows, while remaining secure, extensible, and compatible with Flutter clients.

---

## Table of Contents

1. [Schema Overview](#schema-overview)
2. [Entity Relationships](#entity-relationships)
3. [Tables Summary](#tables-summary)
4. [Database Tables and SQL](#database-tables-and-sql)

   * teams
   * users
   * tasks
   * task_comments
   * tickets
   * ticket_comments
   * meetings
5. [Security Model](#security-model)
6. [Design Decisions](#design-decisions)
7. [Extensibility](#extensibility)

---

## Schema Overview

The database is organized around **teams** as the primary unit of isolation.

Key characteristics:

* Each user belongs to exactly one team
* All operational data is scoped by `team_id`
* Access control is enforced using Row Level Security (RLS)
* Feature-specific tables are preferred over generic polymorphic tables
* AI-generated data is stored alongside its source entity

---

## Entity Relationships

```
teams ──< users
teams ──< tasks ──< task_comments
teams ──< tickets ──< ticket_comments
teams ──< meetings
```

Relationship rules:

* Deleting a team cascades to all related data
* Deleting a task or ticket deletes its associated comments
* Users are referenced via `auth.users.id`

---

## Tables Summary

| Table           | Description                      |
| --------------- | -------------------------------- |
| teams           | Team / workspace metadata        |
| users           | Application user profiles        |
| tasks           | Team tasks                       |
| task_comments   | Comments on tasks                |
| tickets         | Issue and request tracking       |
| ticket_comments | Comments on tickets              |
| meetings        | Meetings with AI processing data |

Total tables: **7**

---

## Database Tables and SQL

### teams

Stores team and workspace information.

```sql
create table teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  team_code text not null unique check (length(team_code) = 6),
  created_at timestamptz default now(),
  created_by uuid not null references auth.users(id),
  admin_name text not null,
  admin_email text not null
);
```

---

### users

Application user profiles linked to Supabase authentication.

```sql
create table users (
  id uuid primary key references auth.users(id),
  full_name text not null,
  email text not null unique,
  team_id uuid not null references teams(id) on delete cascade,
  role text not null check (role in ('admin', 'member')),
  google_refresh_token text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

---

### tasks

Stores tasks created within a team.

```sql
create table tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  status text not null check (status in ('todo', 'in_progress', 'completed')),
  approval_status text not null check (approval_status in ('pending', 'approved', 'rejected')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  due_date timestamptz,
  team_id uuid not null references teams(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  assigned_to uuid references auth.users(id)
);
```

---

### task_comments

Stores comments associated with tasks.

```sql
create table task_comments (
  id uuid primary key default gen_random_uuid(),
  task_id uuid not null references tasks(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  content text not null,
  created_at timestamptz default now()
);
```

---

### tickets

Stores issue and request tickets within a team.

```sql
create table tickets (
  id uuid primary key default gen_random_uuid(),
  ticket_number text not null,
  title text not null,
  description text,
  priority text not null check (priority in ('low', 'medium', 'high')),
  category text,
  status text not null check (status in ('open', 'in_progress', 'resolved')),
  approval_status text not null check (approval_status in ('pending', 'approved', 'rejected')),
  created_by uuid not null references auth.users(id),
  assigned_to uuid references auth.users(id),
  team_id uuid not null references teams(id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
```

---

### ticket_comments

Stores comments associated with tickets.

```sql
create table ticket_comments (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid not null references tickets(id) on delete cascade,
  user_id uuid not null references auth.users(id),
  content text not null,
  created_at timestamptz default now()
);
```

---

### meetings

Stores meetings along with AI transcription, summaries, and embeddings.

```sql
create extension if not exists vector;

create table meetings (
  id uuid primary key default gen_random_uuid(),
  meeting_number text not null,
  title text not null,
  description text,
  meeting_date timestamptz not null,
  meeting_url text,
  transcription text,
  ai_summary text,
  duration_minutes int default 60,
  bot_started_at timestamptz,
  transcription_attempted_at timestamptz,
  transcription_error text,
  created_by uuid not null references auth.users(id),
  team_id uuid not null references teams(id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  final_transcription jsonb,
  meeting_summary_json jsonb,
  summary_embedding vector(768)
);
```

---

## Security Model

* Row Level Security is enabled on all tables
* Access is restricted by:

  * Team membership
  * Record ownership (creator or assignee)
  * Admin role for privileged operations
* Authentication is managed via Supabase `auth.users`

RLS policies are defined in dedicated SQL files and applied per table.

---

## Design Decisions

* No generic `comments` table; comments are feature-specific
* No separate roles or permissions tables; roles are stored on `users`
* No attachment or file tables in the core schema
* AI-generated data is stored directly with meetings for traceability

This reduces complexity while keeping the schema explicit and maintainable.

---

## Extensibility

The schema can be extended without breaking existing clients to support:

* Notifications
* Activity logs
* File attachments
* Meeting comments
* Multi-team membership
* Advanced RBAC

All extensions can be layered on top of the current design.

---

This document defines the authoritative database structure for the Ell-ena application and should be referenced when adding features, writing migrations, or implementing backend logic.
