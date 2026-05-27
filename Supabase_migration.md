# Database Migrations

Schema changes are managed with the [Supabase CLI](https://supabase.com/docs/guides/cli). Every database change lives as a versioned SQL file in `supabase/migrations/` and is committed alongside the Flutter code that uses it.

**Important:** TripManagement and PropertyManagement share the same Supabase project (`qgeocaectbdfonrorwco`). This means `supabase/migrations/` in this repo must contain **all** remote migrations — both PropertyManagement's and TripManagement's. When PropertyManagement adds a new migration, copy that file here too before pushing.

---

## Prerequisites

- Supabase CLI installed: `brew install supabase/tap/supabase`
- Docker Desktop running (required for schema diffing)
- Supabase access token set: `export SUPABASE_ACCESS_TOKEN=<your-token>`
  - Generate at: Supabase Dashboard → Account → Access Tokens
- Project linked: `supabase link --project-ref qgeocaectbdfonrorwco`

---

## Adding a new migration

### 1. Create the migration file

```bash
supabase migration new <description>
# Example:
supabase migration new add_trip_photos
```

This creates `supabase/migrations/<timestamp>_add_trip_photos.sql`.

### 2. Write the SQL

Open the file and write your schema change. Always include RLS policies on new tables.

**New table:**
```sql
create table trip_photos (
  id        uuid primary key default gen_random_uuid(),
  trip_id   uuid not null references trips on delete cascade,
  url       text not null,
  created_at timestamptz not null default now()
);

alter table trip_photos enable row level security;

create policy "trip_photos_select" on trip_photos for select using (
  trip_id in (
    select id from trips
    where created_by = auth.uid()
       or exists (
         select 1 from trip_members
         where trip_members.trip_id = trips.id
           and trip_members.user_id = auth.uid()
       )
  )
);
-- add insert / update / delete policies as needed
```

**Add a column:**
```sql
alter table trips add column if not exists cover_photo_url text;
```

**Add an index:**
```sql
create index if not exists trip_stops_trip_id_idx on trip_stops(trip_id);
```

### 3. Push to remote

```bash
supabase db push
```

Applies only migrations not yet in the remote's migration history. Safe to run multiple times.

### 4. Commit

Commit the migration file in the same PR as the Flutter code that uses it:

```
supabase/migrations/<timestamp>_add_trip_photos.sql
lib/models/trip_photo.dart
lib/providers/trip_provider.dart
...
```

---

## Checking migration status

```bash
supabase migration list
```

Shows which migrations have been applied to the remote.

---

## Re-linking on a new machine or fresh clone

```bash
export SUPABASE_ACCESS_TOKEN=<your-token>
supabase link --project-ref qgeocaectbdfonrorwco
```

---

## Syncing migrations from PropertyManagement

Since both apps share the same Supabase project:

1. When a new migration is added to PropertyManagement's `supabase/migrations/`, copy the `.sql` file to this repo's `supabase/migrations/`.
2. You do **not** need to push it again — it will already be applied. Just keep the files in sync so `supabase migration list` doesn't flag discrepancies.

---

## Important rules

- **Never edit an existing migration file** after it has been pushed — create a new one instead.
- **Never delete a migration file** that has been applied to the remote.
- **Never run SQL directly in the Supabase dashboard** — always use `supabase db push`.
- Always run `supabase db push` before opening a PR so the remote matches the code.
- Every new table **must** have RLS enabled and policies defined.
