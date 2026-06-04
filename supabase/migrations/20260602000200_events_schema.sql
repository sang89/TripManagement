-- Events feature: schema, RLS, and RPCs.
-- Separate from trips — events are single-location, RSVP-centric gatherings.

-- ── events ────────────────────────────────────────────────────────────────────

CREATE TABLE events (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_by  uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  title       text        NOT NULL,
  description text        NOT NULL DEFAULT '',
  location    text        NOT NULL DEFAULT '',
  location_lat  double precision,
  location_lng  double precision,
  start_at    timestamptz NOT NULL,
  end_at      timestamptz,
  capacity    integer,                    -- NULL = unlimited
  invite_code uuid        NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE events ENABLE ROW LEVEL SECURITY;

-- ── event_guests ──────────────────────────────────────────────────────────────

CREATE TABLE event_guests (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id     uuid        NOT NULL REFERENCES events ON DELETE CASCADE,
  user_id      uuid        REFERENCES auth.users ON DELETE SET NULL,  -- NULL for non-app RSVPs
  display_name text        NOT NULL,
  email        text,
  phone        text,
  rsvp_status  text        NOT NULL DEFAULT 'going'
                           CHECK (rsvp_status IN ('going', 'maybe', 'declined')),
  rsvp_at      timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- Only one row per authenticated user per event.
CREATE UNIQUE INDEX event_guests_event_user_unique
  ON event_guests (event_id, user_id)
  WHERE user_id IS NOT NULL;

ALTER TABLE event_guests ENABLE ROW LEVEL SECURITY;

-- ── event_messages ────────────────────────────────────────────────────────────

CREATE TABLE event_messages (
  id        uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id  uuid        NOT NULL REFERENCES events ON DELETE CASCADE,
  user_id   uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  content   text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX event_messages_event_created ON event_messages (event_id, created_at DESC);

ALTER TABLE event_messages ENABLE ROW LEVEL SECURITY;

-- ── event_photos ──────────────────────────────────────────────────────────────

CREATE TABLE event_photos (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id     uuid        NOT NULL REFERENCES events ON DELETE CASCADE,
  uploaded_by  uuid        NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  storage_path text        NOT NULL,      -- bucket: event-photos; path: {event_id}/{id}.jpg
  caption      text        NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE event_photos ENABLE ROW LEVEL SECURITY;

-- ── event_expenses ────────────────────────────────────────────────────────────

CREATE TABLE event_expenses (
  id               uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id         uuid           NOT NULL REFERENCES events ON DELETE CASCADE,
  paid_by_user_id  uuid           NOT NULL REFERENCES auth.users ON DELETE CASCADE,
  paid_by_name     text           NOT NULL,
  amount           numeric(10,2)  NOT NULL CHECK (amount > 0),
  description      text           NOT NULL,
  created_at       timestamptz    NOT NULL DEFAULT now()
);

ALTER TABLE event_expenses ENABLE ROW LEVEL SECURITY;

-- ── event_expense_splits ──────────────────────────────────────────────────────

CREATE TABLE event_expense_splits (
  id          uuid           PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid           NOT NULL REFERENCES events ON DELETE CASCADE,  -- denormalized for RLS
  expense_id  uuid           NOT NULL REFERENCES event_expenses ON DELETE CASCADE,
  guest_id    uuid           NOT NULL REFERENCES event_guests ON DELETE CASCADE,
  amount      numeric(10,2)  NOT NULL CHECK (amount > 0),
  settled     boolean        NOT NULL DEFAULT false,
  settled_at  timestamptz
);

ALTER TABLE event_expense_splits ENABLE ROW LEVEL SECURITY;

-- ── RLS helper ────────────────────────────────────────────────────────────────

-- True if the calling authenticated user is the event creator OR has a guest row.
CREATE FUNCTION auth_user_is_event_member(p_event_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM events      WHERE id = p_event_id AND created_by = auth.uid()
    UNION ALL
    SELECT 1 FROM event_guests WHERE event_id = p_event_id AND user_id = auth.uid()
  );
$$;

REVOKE EXECUTE ON FUNCTION auth_user_is_event_member(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION auth_user_is_event_member(uuid) TO authenticated;

-- ── events RLS policies ───────────────────────────────────────────────────────

CREATE POLICY "events_select" ON events
  FOR SELECT USING (auth_user_is_event_member(id));

CREATE POLICY "events_insert" ON events
  FOR INSERT WITH CHECK (created_by = auth.uid());

CREATE POLICY "events_update" ON events
  FOR UPDATE USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

CREATE POLICY "events_delete" ON events
  FOR DELETE USING (created_by = auth.uid());

-- ── event_guests RLS policies ─────────────────────────────────────────────────

CREATE POLICY "event_guests_select" ON event_guests
  FOR SELECT USING (auth_user_is_event_member(event_id));

-- Organizer can add guests; authenticated users can add themselves.
CREATE POLICY "event_guests_insert" ON event_guests
  FOR INSERT WITH CHECK (
    (SELECT created_by FROM events WHERE id = event_id) = auth.uid()
    OR user_id = auth.uid()
  );

-- Organizer can update any guest; each user can update their own RSVP.
CREATE POLICY "event_guests_update" ON event_guests
  FOR UPDATE USING (
    (SELECT created_by FROM events WHERE id = event_id) = auth.uid()
    OR user_id = auth.uid()
  );

-- Organizer can remove any guest; each user can remove themselves.
CREATE POLICY "event_guests_delete" ON event_guests
  FOR DELETE USING (
    (SELECT created_by FROM events WHERE id = event_id) = auth.uid()
    OR user_id = auth.uid()
  );

-- ── event_messages RLS policies ───────────────────────────────────────────────

CREATE POLICY "event_messages_select" ON event_messages
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "event_messages_insert" ON event_messages
  FOR INSERT WITH CHECK (
    auth_user_is_event_member(event_id) AND user_id = auth.uid()
  );

-- No UPDATE or DELETE — messages are permanent.

-- ── event_photos RLS policies ─────────────────────────────────────────────────

CREATE POLICY "event_photos_select" ON event_photos
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "event_photos_insert" ON event_photos
  FOR INSERT WITH CHECK (
    auth_user_is_event_member(event_id) AND uploaded_by = auth.uid()
  );

CREATE POLICY "event_photos_delete" ON event_photos
  FOR DELETE USING (
    uploaded_by = auth.uid()
    OR (SELECT created_by FROM events WHERE id = event_id) = auth.uid()
  );

-- ── event_expenses RLS policies ───────────────────────────────────────────────

CREATE POLICY "event_expenses_select" ON event_expenses
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "event_expenses_insert" ON event_expenses
  FOR INSERT WITH CHECK (
    auth_user_is_event_member(event_id) AND paid_by_user_id = auth.uid()
  );

CREATE POLICY "event_expenses_delete" ON event_expenses
  FOR DELETE USING (
    paid_by_user_id = auth.uid()
    OR (SELECT created_by FROM events WHERE id = event_id) = auth.uid()
  );

-- ── event_expense_splits RLS policies ────────────────────────────────────────

CREATE POLICY "event_expense_splits_select" ON event_expense_splits
  FOR SELECT USING (auth_user_is_event_member(event_id));

CREATE POLICY "event_expense_splits_insert" ON event_expense_splits
  FOR INSERT WITH CHECK (auth_user_is_event_member(event_id));

-- Payer or organizer can settle.
CREATE POLICY "event_expense_splits_update" ON event_expense_splits
  FOR UPDATE USING (auth_user_is_event_member(event_id));

-- ── Public RSVP RPC (no auth required) ───────────────────────────────────────
-- Used by EventInviteScreen for guests who don't have an account.

CREATE FUNCTION rsvp_event_public(
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

  -- Enforce capacity only for 'going' RSVPs.
  IF p_rsvp_status = 'going' AND v_capacity IS NOT NULL THEN
    SELECT COUNT(*) INTO v_going
      FROM event_guests
     WHERE event_guests.event_id = v_event_id AND rsvp_status = 'going';
    IF v_going >= v_capacity THEN
      RAISE EXCEPTION 'event_full';
    END IF;
  END IF;

  INSERT INTO event_guests (event_id, display_name, email, phone, rsvp_status)
  VALUES (v_event_id, p_display_name, p_email, p_phone, p_rsvp_status);

  RETURN QUERY
    SELECT e.id,
           e.title,
           e.description,
           e.location,
           e.start_at,
           e.end_at,
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.rsvp_status = 'going'),
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.rsvp_status = 'maybe')
      FROM events e
     WHERE e.id = v_event_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION rsvp_event_public(uuid, text, text, text, text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION rsvp_event_public(uuid, text, text, text, text) TO anon;
GRANT  EXECUTE ON FUNCTION rsvp_event_public(uuid, text, text, text, text) TO authenticated;

-- Fetches public event info by invite code — no auth required.
CREATE FUNCTION get_event_by_invite_code(p_invite_code uuid)
RETURNS TABLE(
  event_id    uuid,
  title       text,
  description text,
  location    text,
  location_lat  double precision,
  location_lng  double precision,
  start_at    timestamptz,
  end_at      timestamptz,
  capacity    integer,
  going_count bigint,
  maybe_count bigint,
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
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.rsvp_status = 'going'),
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.rsvp_status = 'maybe'),
           (SELECT COUNT(*) FROM event_guests g WHERE g.event_id = e.id AND g.rsvp_status = 'declined'),
           COALESCE(NULLIF(TRIM(up.full_name), ''), 'Unknown')
      FROM events e
      LEFT JOIN user_profiles up ON up.user_id = e.created_by
     WHERE e.invite_code = p_invite_code;
END;
$$;

REVOKE EXECUTE ON FUNCTION get_event_by_invite_code(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION get_event_by_invite_code(uuid) TO anon;
GRANT  EXECUTE ON FUNCTION get_event_by_invite_code(uuid) TO authenticated;
