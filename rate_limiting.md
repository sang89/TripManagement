# Rate Limiting

## Overview

TripManagement applies rate limiting at the **Supabase / PostgreSQL layer** for
sensitive RPCs, and relies on Supabase's built-in JWT verification for all
authenticated endpoints.

---

## rsvp_session (B13)

### Problem
`rsvp_session` was previously granted to both `anon` and `authenticated` roles.
An unauthenticated caller could spam a session with fake roster entries (each
with `user_id = NULL`) because there was no per-user or per-IP cap.

### Fix applied (migration `20260617000002_fix_rsvp_capacity_race.sql`)
- **Removed the `anon` grant** — `REVOKE EXECUTE … FROM anon`.
- `rsvp_session` now raises `auth_required` when `auth.uid() IS NULL`.
- All signups require a valid Supabase JWT (`authenticated` role).
- The Flutter app already redirects anonymous users to `/login` before calling
  the RPC; this migration makes the server enforce the same rule.

### Public invite flow
The `session_invite_screen` and `session_scan_screen` routes call `rsvp_session`
using the **logged-in user's JWT**. Anonymous visitors who follow a public invite
link must create an account (or log in) before signing up. This is acceptable
for the current product; if a truly guest-signup flow is added in the future,
re-add the `anon` grant with the safeguards below.

### Future: if anon signups are re-enabled
Add a per-IP rate-limit check using a dedicated table:

```sql
CREATE TABLE signup_rate_limits (
  ip_addr      text        NOT NULL,
  window_start timestamptz NOT NULL DEFAULT date_trunc('minute', now()),
  attempts     int         NOT NULL DEFAULT 1,
  PRIMARY KEY (ip_addr, window_start)
);

-- Inside rsvp_session, before any INSERT:
IF auth.uid() IS NULL THEN
  DECLARE v_ip text; v_count int;
  BEGIN
    v_ip := coalesce(
      current_setting('request.headers', true)::json->>'x-forwarded-for',
      'unknown'
    );
    INSERT INTO signup_rate_limits (ip_addr, window_start, attempts)
    VALUES (v_ip, date_trunc('minute', now()), 1)
    ON CONFLICT (ip_addr, window_start)
    DO UPDATE SET attempts = signup_rate_limits.attempts + 1
    RETURNING attempts INTO v_count;
    IF v_count > 5 THEN RAISE EXCEPTION 'rate_limited'; END IF;
  END;
END IF;
```

Limits: **5 anonymous signups per IP per minute**. Adjust as needed.
Add a `pg_cron` job to purge rows older than 1 hour:

```sql
SELECT cron.schedule('cleanup-rate-limits', '*/15 * * * *',
  $$DELETE FROM signup_rate_limits WHERE window_start < now() - interval '1 hour'$$);
```

---

## Other RPCs

| RPC | Auth required | Notes |
|-----|--------------|-------|
| `rsvp_session` | ✅ `authenticated` only (since `20260617000002`) | Capacity serialised via `FOR UPDATE` on `event_sessions` |
| `cancel_session_signup` | ✅ `authenticated` only | Only affects the caller's own roster entry |
| `session_remove_roster_entry` | ✅ `authenticated` + organizer check | |
| `session_approve_request` | ✅ `authenticated` + organizer check | |
| `session_reject_request` | ✅ `authenticated` + organizer check | |
| `delete_event_session` | ✅ `authenticated` + organizer check | |
| `add_event_session` | ✅ `authenticated` + organizer check | |

All organizer-gated RPCs use `SECURITY DEFINER` and verify
`EXISTS (SELECT 1 FROM events WHERE id = … AND created_by = auth.uid())`.

---

## Supabase platform-level limits

Supabase Pro plan enforces:
- **500 requests / second** per project (shared across all clients)
- **Row Level Security** is applied to all direct table access

For higher-traffic scenarios, add an **API Gateway** (e.g. Cloudflare Workers)
in front of the Supabase REST endpoint to enforce per-user rate limits before
requests reach the database.
