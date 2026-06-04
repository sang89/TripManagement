-- ─────────────────────────────────────────────────────────────────────────────
-- Unify Trips into the Events system.
--
-- Events become the single model for all social experiences.
-- event_type enum: trip, birthday, wedding, social.
-- trip_stops    → event_stops   (trip-specific itinerary)
-- trip_members  → event_guests  (invite flow extended with status/role)
-- trip_messages → event_messages (chat unified)
--
-- 20260604000100 (trip_photos_expenses) was NEVER pushed, so no trip_photos /
-- trip_expense rows exist — photos and expenses continue on event_photos /
-- event_expenses / event_expense_splits.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. Event type enum ────────────────────────────────────────────────────────

CREATE TYPE event_type AS ENUM ('trip', 'birthday', 'wedding', 'social');

ALTER TABLE events
  ADD COLUMN event_type event_type NOT NULL DEFAULT 'social';

-- ── 2. Trip-origin fields on events ───────────────────────────────────────────
-- Only populated when event_type = 'trip'.
-- The trip destination maps to the existing location / location_lat / location_lng.

ALTER TABLE events
  ADD COLUMN start_location text,
  ADD COLUMN start_lat      double precision,
  ADD COLUMN start_lng      double precision;

-- ── 3. Extend event_guests for the trip invite flow ───────────────────────────
-- Rename rsvp_status → status and expand the allowed values.
-- Non-trip events use:  going | maybe | declined
-- Trip-type events use: pending | accepted | declined | left

ALTER TABLE event_guests DROP CONSTRAINT event_guests_rsvp_status_check;
ALTER TABLE event_guests RENAME COLUMN rsvp_status TO status;
ALTER TABLE event_guests ALTER COLUMN status SET DEFAULT 'going';
ALTER TABLE event_guests ADD CONSTRAINT event_guests_status_check
  CHECK (status IN ('going', 'maybe', 'declined', 'pending', 'accepted', 'left'));

ALTER TABLE event_guests
  ADD COLUMN invited_by    uuid    REFERENCES auth.users ON DELETE SET NULL,
  ADD COLUMN block_reinvite boolean NOT NULL DEFAULT false,
  ADD COLUMN role           text    NOT NULL DEFAULT 'member';

-- Replace the partial unique INDEX with a full unique CONSTRAINT so PostgREST
-- can target it in ON CONFLICT clauses (upsert for reinvite flow).
-- PostgreSQL treats NULL as distinct in unique constraints, so multiple rows
-- with user_id = NULL (unlinked guests) are still allowed per event.
DROP INDEX IF EXISTS event_guests_event_user_unique;
ALTER TABLE event_guests
  ADD CONSTRAINT event_guests_event_user_unique UNIQUE (event_id, user_id);

-- ── 4. Block-reinvite guard on event_guests ───────────────────────────────────

CREATE OR REPLACE FUNCTION public.prevent_blocked_event_reinvite()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.block_reinvite = true
     AND NEW.status = 'pending' THEN
    RAISE EXCEPTION 'blocked_reinvite'
      USING DETAIL = 'User has opted out of future invitations to this event';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_event_guest_reinvite_check
  BEFORE UPDATE ON public.event_guests
  FOR EACH ROW EXECUTE FUNCTION public.prevent_blocked_event_reinvite();

-- ── 5. Invite notification trigger on event_guests ────────────────────────────
-- Mirrors handle_new_invite() on trip_members. Fires the send-invite-notification
-- Edge Function whenever a guest row transitions to status = 'pending'.

CREATE OR REPLACE FUNCTION public.handle_new_event_invite()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_service_role_key text;
BEGIN
  IF NEW.status = 'pending' AND NEW.user_id IS NOT NULL AND
     (TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'pending')) THEN

    SELECT decrypted_secret INTO v_service_role_key
    FROM vault.decrypted_secrets
    WHERE name = 'service_role_key'
    LIMIT 1;

    IF v_service_role_key IS NOT NULL THEN
      PERFORM net.http_post(
        url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                   || '/functions/v1/send-invite-notification',
        headers := jsonb_build_object(
          'Content-Type',  'application/json',
          'Authorization', 'Bearer ' || v_service_role_key
        ),
        body    := jsonb_build_object(
          'guest_id',        NEW.id,
          'event_id',        NEW.event_id,
          'invitee_user_id', NEW.user_id
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_event_guest_invite
  AFTER INSERT OR UPDATE ON public.event_guests
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_event_invite();

-- ── 6. Reinvite policy on event_guests ────────────────────────────────────────
-- Allows the organizer or any accepted member to reinvite a guest whose status
-- is 'left' or 'declined'. Mirrors trip_members_reinvite policy.

CREATE POLICY "event_guests_reinvite" ON event_guests
  FOR UPDATE
  USING (
    status IN ('left', 'declined')
    AND (
      event_id IN (SELECT id FROM events WHERE created_by = auth.uid())
      OR auth_user_is_event_member(event_id)
    )
  )
  WITH CHECK (status = 'pending');

-- ── 7. event_stops table ──────────────────────────────────────────────────────

CREATE TABLE event_stops (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid        NOT NULL REFERENCES events ON DELETE CASCADE,
  title       text        NOT NULL,
  address     text        NOT NULL DEFAULT '',
  address_lat double precision,
  address_lng double precision,
  arrive_at   timestamptz,
  depart_at   timestamptz,
  notes       text        NOT NULL DEFAULT '',
  sort_order  integer     NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE event_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_stops REPLICA IDENTITY FULL;

-- ── 8. Update auth_user_is_event_member ───────────────────────────────────────
-- Include pending guests so invitees can view the event before accepting.
-- 'declined' and 'left' guests lose access (same behaviour as trip members).

CREATE OR REPLACE FUNCTION auth_user_is_event_member(p_event_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM events WHERE id = p_event_id AND created_by = auth.uid()
    UNION ALL
    SELECT 1 FROM event_guests
    WHERE event_id = p_event_id
      AND user_id  = auth.uid()
      AND status  IN ('going', 'maybe', 'accepted', 'pending')
  );
$$;

-- ── 9. RLS for event_stops ────────────────────────────────────────────────────

CREATE POLICY "event_stops_select" ON event_stops
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "event_stops_insert" ON event_stops
  FOR INSERT WITH CHECK (auth_user_is_event_member(event_id));

CREATE POLICY "event_stops_update" ON event_stops
  FOR UPDATE USING (auth_user_is_event_member(event_id));

CREATE POLICY "event_stops_delete" ON event_stops
  FOR DELETE USING (
    (SELECT created_by FROM events WHERE id = event_id) = auth.uid()
    OR auth_user_is_event_member(event_id)
  );

-- ── 10. Realtime for event_stops ──────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE event_stops;

-- ── 11. Update create_event RPC ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION create_event(
  p_title          text,
  p_description    text,
  p_location       text,
  p_start_at       timestamptz,
  p_location_lat   double precision DEFAULT NULL,
  p_location_lng   double precision DEFAULT NULL,
  p_end_at         timestamptz      DEFAULT NULL,
  p_capacity       integer          DEFAULT NULL,
  p_event_type     event_type       DEFAULT 'social',
  p_start_location text             DEFAULT NULL,
  p_start_lat      double precision DEFAULT NULL,
  p_start_lng      double precision DEFAULT NULL
)
RETURNS TABLE (
  id             uuid,
  created_by     uuid,
  title          text,
  description    text,
  location       text,
  location_lat   double precision,
  location_lng   double precision,
  start_at       timestamptz,
  end_at         timestamptz,
  capacity       integer,
  invite_code    uuid,
  created_at     timestamptz,
  updated_at     timestamptz,
  event_type     event_type,
  start_location text,
  start_lat      double precision,
  start_lng      double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated'
      USING HINT = 'You must be signed in to create an event.';
  END IF;

  RETURN QUERY
    INSERT INTO events (
      created_by, title, description, location,
      location_lat, location_lng,
      start_at, end_at, capacity,
      event_type, start_location, start_lat, start_lng
    )
    VALUES (
      v_uid, p_title, p_description, p_location,
      p_location_lat, p_location_lng,
      p_start_at, p_end_at, p_capacity,
      p_event_type, p_start_location, p_start_lat, p_start_lng
    )
    RETURNING
      events.id, events.created_by, events.title, events.description,
      events.location, events.location_lat, events.location_lng,
      events.start_at, events.end_at, events.capacity, events.invite_code,
      events.created_at, events.updated_at,
      events.event_type, events.start_location, events.start_lat, events.start_lng;
END;
$$;

-- ── 12. Update rsvp_event_public RPC (rsvp_status → status rename) ───────────

CREATE OR REPLACE FUNCTION rsvp_event_public(
  p_invite_code  uuid,
  p_display_name text,
  p_email        text,
  p_phone        text,
  p_rsvp_status  text DEFAULT 'going'
)
RETURNS TABLE(
  event_id    uuid,
  title       text,
  description text,
  location    text,
  start_at    timestamptz,
  end_at      timestamptz,
  going_count bigint,
  maybe_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event_id uuid;
  v_capacity integer;
  v_going    bigint;
BEGIN
  IF p_rsvp_status NOT IN ('going', 'maybe', 'declined') THEN
    RAISE EXCEPTION 'invalid rsvp_status';
  END IF;

  SELECT e.id, e.capacity
    INTO v_event_id, v_capacity
    FROM events e
   WHERE e.invite_code = p_invite_code;

  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'event not found';
  END IF;

  IF p_rsvp_status = 'going' AND v_capacity IS NOT NULL THEN
    SELECT COUNT(*) INTO v_going
      FROM event_guests
     WHERE event_guests.event_id = v_event_id AND status = 'going';
    IF v_going >= v_capacity THEN
      RAISE EXCEPTION 'event_full';
    END IF;
  END IF;

  INSERT INTO event_guests (event_id, display_name, email, phone, status)
  VALUES (v_event_id, p_display_name, p_email, p_phone, p_rsvp_status);

  RETURN QUERY
    SELECT e.id,
           e.title,
           e.description,
           e.location,
           e.start_at,
           e.end_at,
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.status = 'going'),
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.status = 'maybe')
      FROM events e
     WHERE e.id = v_event_id;
END;
$$;

-- ── 13. Update get_event_by_invite_code RPC (rsvp_status → status rename) ─────

CREATE OR REPLACE FUNCTION get_event_by_invite_code(p_invite_code uuid)
RETURNS TABLE(
  event_id       uuid,
  title          text,
  description    text,
  location       text,
  location_lat   double precision,
  location_lng   double precision,
  start_at       timestamptz,
  end_at         timestamptz,
  capacity       integer,
  going_count    bigint,
  maybe_count    bigint,
  declined_count bigint,
  organizer_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT e.id,
           e.title,
           e.description,
           e.location,
           e.location_lat,
           e.location_lng,
           e.start_at,
           e.end_at,
           e.capacity,
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.status = 'going'),
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.status = 'maybe'),
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.status = 'declined'),
           COALESCE(NULLIF(TRIM(up.full_name), ''), 'Unknown')
      FROM events e
      LEFT JOIN user_profiles up ON up.user_id = e.created_by
     WHERE e.invite_code = p_invite_code;
END;
$$;

-- ── 14. resend_event_invite RPC ────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.resend_event_invite(p_guest_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_guest      event_guests%rowtype;
  v_authorized boolean;
  v_svc_key    text;
BEGIN
  SELECT * INTO v_guest FROM event_guests WHERE id = p_guest_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'guest_not_found';
  END IF;

  IF v_guest.status <> 'pending' OR v_guest.user_id IS NULL THEN
    RAISE EXCEPTION 'not_pending_linked_invite';
  END IF;

  SELECT (
    EXISTS (SELECT 1 FROM events WHERE id = v_guest.event_id AND created_by = auth.uid())
    OR auth_user_is_event_member(v_guest.event_id)
  ) INTO v_authorized;

  IF NOT v_authorized THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  SELECT decrypted_secret INTO v_svc_key
  FROM vault.decrypted_secrets
  WHERE name = 'service_role_key'
  LIMIT 1;

  IF v_svc_key IS NOT NULL THEN
    PERFORM net.http_post(
      url     := 'https://qgeocaectbdfonrorwco.supabase.co'
                 || '/functions/v1/send-invite-notification',
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_svc_key
      ),
      body    := jsonb_build_object(
        'guest_id',        p_guest_id,
        'event_id',        v_guest.event_id,
        'invitee_user_id', v_guest.user_id
      )
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resend_event_invite(uuid) TO authenticated;

-- ── 15. Migrate trips → events ────────────────────────────────────────────────

INSERT INTO events (
  id, created_by, title, description, location,
  location_lat, location_lng,
  start_at, end_at,
  invite_code, created_at, updated_at,
  event_type, start_location, start_lat, start_lng
)
SELECT
  t.id,
  t.created_by,
  t.title,
  COALESCE(t.notes, ''),
  COALESCE(t.destination, ''),
  t.destination_lat,
  t.destination_lng,
  COALESCE(t.start_at, now()),   -- events.start_at is NOT NULL
  t.end_at,
  gen_random_uuid(),
  t.created_at,
  t.updated_at,
  'trip',
  t.start_location,
  t.start_lat,
  t.start_lng
FROM trips t
ON CONFLICT (id) DO NOTHING;

-- ── 16. Migrate trip_members → event_guests ────────────────────────────────────

INSERT INTO event_guests (
  id, event_id, user_id, display_name, email, phone,
  status, invited_by, block_reinvite, role,
  rsvp_at, created_at
)
SELECT
  tm.id,
  tm.trip_id,
  tm.user_id,
  tm.display_name,
  tm.email,
  tm.phone,
  CASE tm.status
    WHEN 'accepted' THEN 'accepted'
    WHEN 'pending'  THEN 'pending'
    WHEN 'declined' THEN 'declined'
    WHEN 'left'     THEN 'left'
    ELSE 'accepted'
  END,
  tm.invited_by,
  COALESCE(tm.block_reinvite, false),
  COALESCE(tm.role, 'member'),
  tm.created_at,
  tm.created_at
FROM trip_members tm
ON CONFLICT DO NOTHING;

-- ── 17. Migrate trip_stops → event_stops ──────────────────────────────────────

INSERT INTO event_stops (
  id, event_id, title, address, address_lat, address_lng,
  arrive_at, depart_at, notes, sort_order, created_at
)
SELECT
  ts.id, ts.trip_id, ts.title, ts.address,
  ts.address_lat, ts.address_lng,
  ts.arrive_at, ts.depart_at, ts.notes, ts.sort_order, ts.created_at
FROM trip_stops ts
ON CONFLICT DO NOTHING;

-- ── 18. Migrate trip_messages → event_messages ────────────────────────────────
-- Trip IDs are preserved as event IDs (see step 15), so trip_id = event_id here.

INSERT INTO event_messages (id, event_id, user_id, content, created_at)
SELECT tm.id, tm.trip_id, tm.user_id, tm.content, tm.created_at
FROM trip_messages tm
ON CONFLICT DO NOTHING;

-- ── 19. Drop old trip tables ──────────────────────────────────────────────────
-- CASCADE drops attached triggers. trip_members / trip_stops / trip_messages
-- cascade-delete from trips, but they are already empty / dropped first.

DROP TABLE IF EXISTS trip_stops    CASCADE;
DROP TABLE IF EXISTS trip_messages CASCADE;
DROP TABLE IF EXISTS trip_members  CASCADE;
DROP TABLE IF EXISTS trips         CASCADE;

-- ── 20. Drop old trip functions ────────────────────────────────────────────────

DROP FUNCTION IF EXISTS auth_user_is_trip_member(uuid);
DROP FUNCTION IF EXISTS auth_user_has_pending_invite(uuid);
DROP FUNCTION IF EXISTS resend_invite(uuid);
DROP FUNCTION IF EXISTS handle_new_invite();
DROP FUNCTION IF EXISTS prevent_blocked_reinvite();
