-- Paid session registration: Stripe Connect Express + three payment modes.
--
-- payment_mode (on event_sessions):
--   'free'       — no fee, payment_status always 'not_required'
--   'pay_first'  — Stripe payment required before roster spot is inserted
--   'join_first' — roster inserted immediately, payment expected later (pay link shown)
--   'track_only' — free to join, organizer manually marks paid/unpaid (cash etc.)
--
-- payment_status (on event_session_roster):
--   'not_required' — free session
--   'unpaid'       — join_first or track_only: spot reserved, payment pending
--   'paid'         — payment confirmed (Stripe or manual mark)
--   'refunded'     — Stripe refund issued (future use)

-- ── 1. Organizer Stripe Connect columns ──────────────────────────────────────

ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS stripe_connect_account_id text,
  ADD COLUMN IF NOT EXISTS stripe_connect_charges_enabled boolean NOT NULL DEFAULT false;

-- ── 2. Session pricing columns ────────────────────────────────────────────────

ALTER TABLE event_sessions
  ADD COLUMN IF NOT EXISTS price_cents  integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS currency     text    NOT NULL DEFAULT 'usd',
  ADD COLUMN IF NOT EXISTS payment_mode text    NOT NULL DEFAULT 'free';

ALTER TABLE event_sessions
  DROP CONSTRAINT IF EXISTS event_sessions_payment_mode_check;

ALTER TABLE event_sessions
  ADD CONSTRAINT event_sessions_payment_mode_check
  CHECK (payment_mode IN ('free', 'pay_first', 'join_first', 'track_only'));

-- ── 3. Roster payment tracking columns ───────────────────────────────────────

ALTER TABLE event_session_roster
  ADD COLUMN IF NOT EXISTS payment_status           text DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS stripe_payment_intent_id text,
  ADD COLUMN IF NOT EXISTS paid_at                  timestamptz;

-- Backfill existing rows
UPDATE event_session_roster SET payment_status = 'not_required' WHERE payment_status IS NULL;

ALTER TABLE event_session_roster
  ALTER COLUMN payment_status SET NOT NULL,
  ALTER COLUMN payment_status SET DEFAULT 'not_required';

ALTER TABLE event_session_roster
  DROP CONSTRAINT IF EXISTS event_session_roster_payment_status_check;

ALTER TABLE event_session_roster
  ADD CONSTRAINT event_session_roster_payment_status_check
  CHECK (payment_status IN ('not_required', 'unpaid', 'paid', 'refunded'));

-- ── 4. Update add_event_session — accept payment fields ──────────────────────
-- Must DROP first because the RETURNS TABLE signature changes.

DROP FUNCTION IF EXISTS add_event_session(uuid,timestamptz,timestamptz,integer,boolean,integer,boolean,boolean);

CREATE OR REPLACE FUNCTION add_event_session(
  p_event_id           uuid,
  p_start_at           timestamptz,
  p_end_at             timestamptz DEFAULT NULL,
  p_capacity           integer     DEFAULT NULL,
  p_waitlist_enabled   boolean     DEFAULT true,
  p_signup_lock_hours  integer     DEFAULT NULL,
  p_is_public          boolean     DEFAULT true,
  p_requires_approval  boolean     DEFAULT false,
  p_price_cents        integer     DEFAULT 0,
  p_currency           text        DEFAULT 'usd',
  p_payment_mode       text        DEFAULT 'free'
)
RETURNS TABLE(
  id                uuid,
  event_id          uuid,
  session_number    integer,
  start_at          timestamptz,
  end_at            timestamptz,
  invite_code       uuid,
  created_at        timestamptz,
  going_count       integer,
  waitlist_count    integer,
  capacity          integer,
  waitlist_enabled  boolean,
  signup_lock_hours integer,
  is_public         boolean,
  requires_approval boolean,
  price_cents       integer,
  currency          text,
  payment_mode      text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_next_num integer;
BEGIN
  -- Use table alias to avoid ambiguity with output column 'id'.
  IF NOT EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = p_event_id AND e.created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  SELECT COALESCE(MAX(es.session_number), 0) + 1 INTO v_next_num
  FROM event_sessions es WHERE es.event_id = p_event_id;

  RETURN QUERY
    INSERT INTO event_sessions
      (event_id, session_number, start_at, end_at, capacity, waitlist_enabled,
       signup_lock_hours, is_public, requires_approval,
       price_cents, currency, payment_mode)
    VALUES
      (p_event_id, v_next_num, p_start_at, p_end_at, p_capacity, p_waitlist_enabled,
       p_signup_lock_hours, p_is_public, p_requires_approval,
       p_price_cents, p_currency, p_payment_mode)
    RETURNING
      event_sessions.id, event_sessions.event_id, event_sessions.session_number,
      event_sessions.start_at, event_sessions.end_at, event_sessions.invite_code,
      event_sessions.created_at,
      event_sessions.going_count::integer, event_sessions.waitlist_count::integer,
      event_sessions.capacity, event_sessions.waitlist_enabled,
      event_sessions.signup_lock_hours, event_sessions.is_public,
      event_sessions.requires_approval,
      event_sessions.price_cents, event_sessions.currency, event_sessions.payment_mode;
END;
$$;

GRANT EXECUTE ON FUNCTION add_event_session(uuid,timestamptz,timestamptz,integer,boolean,integer,boolean,boolean,integer,text,text)
  TO authenticated;

-- ── 5. Update get_session_by_invite_code — return payment fields ──────────────

DROP FUNCTION IF EXISTS get_session_by_invite_code(uuid);

CREATE OR REPLACE FUNCTION get_session_by_invite_code(p_invite_code uuid)
RETURNS TABLE(
  session_id                     uuid,
  event_id                       uuid,
  session_number                 integer,
  title                          text,
  description                    text,
  location                       text,
  location_lat                   double precision,
  location_lng                   double precision,
  start_at                       timestamptz,
  end_at                         timestamptz,
  capacity                       integer,
  going_count                    bigint,
  waitlist_count                 bigint,
  organizer_name                 text,
  waitlist_enabled               boolean,
  signup_lock_hours              integer,
  price_cents                    integer,
  currency                       text,
  payment_mode                   text,
  organizer_charges_enabled      boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    s.id,
    e.id,
    s.session_number,
    e.title,
    e.description,
    e.location,
    e.location_lat,
    e.location_lng,
    s.start_at,
    s.end_at,
    s.capacity,
    COUNT(*) FILTER (WHERE r.status = 'going')      AS going_count,
    COUNT(*) FILTER (WHERE r.status = 'waitlisted') AS waitlist_count,
    (
      SELECT COALESCE(NULLIF(TRIM(up2.full_name), ''), u2.email)
      FROM auth.users u2
      LEFT JOIN user_profiles up2 ON up2.user_id = u2.id
      WHERE u2.id = e.created_by
    ) AS organizer_name,
    s.waitlist_enabled,
    s.signup_lock_hours,
    s.price_cents,
    s.currency,
    s.payment_mode,
    COALESCE(up.stripe_connect_charges_enabled, false) AS organizer_charges_enabled
  FROM event_sessions s
  JOIN events e ON e.id = s.event_id
  LEFT JOIN user_profiles up ON up.user_id = e.created_by
  LEFT JOIN event_session_roster r ON r.session_id = s.id
  WHERE s.invite_code = p_invite_code
  GROUP BY s.id, s.session_number, s.start_at, s.end_at, s.capacity,
           s.waitlist_enabled, s.signup_lock_hours,
           s.price_cents, s.currency, s.payment_mode,
           e.id, e.title, e.description, e.location,
           e.location_lat, e.location_lng, e.created_by,
           up.stripe_connect_charges_enabled;
$$;

GRANT EXECUTE ON FUNCTION get_session_by_invite_code(uuid) TO anon, authenticated;

-- ── 6. Update rsvp_session — honour payment_mode ──────────────────────────────
-- Must DROP first: adding p_payment_intent_id changes the signature.
--
DROP FUNCTION IF EXISTS rsvp_session(uuid, text, text, text);
--
-- New optional p_payment_intent_id:
--   pay_first  + no intent  → raise 'payment_required' (app must go through Stripe first)
--   pay_first  + intent     → insert with payment_status='paid' (called by webhook)
--   join_first / track_only → insert with payment_status='unpaid'
--   free                    → insert with payment_status='not_required'

CREATE OR REPLACE FUNCTION rsvp_session(
  p_invite_code         uuid,
  p_display_name        text,
  p_email               text DEFAULT NULL,
  p_phone               text DEFAULT NULL,
  p_payment_intent_id   text DEFAULT NULL
)
RETURNS TABLE(
  roster_id        uuid,
  signup_position  integer,
  rsvp_status      text,
  confirmed_count  bigint,
  waitlist_count   bigint,
  session_capacity integer
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_session      event_sessions%ROWTYPE;
  v_event_type   event_type;
  v_confirmed    bigint;
  v_waitlisted   bigint;
  v_next_order   integer;
  v_status       text;
  v_pay_status   text;
  v_roster_id    uuid := gen_random_uuid();
  v_user_id      uuid := auth.uid();
BEGIN
  SELECT * INTO v_session
  FROM event_sessions WHERE invite_code = p_invite_code FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;

  SELECT event_type INTO v_event_type FROM events WHERE id = v_session.event_id;
  IF v_event_type <> 'signup' THEN RAISE EXCEPTION 'not_a_signup_event'; END IF;

  IF v_session.signup_lock_hours IS NOT NULL THEN
    IF now() >= (v_session.start_at - (v_session.signup_lock_hours || ' hours')::interval) THEN
      RAISE EXCEPTION 'signup_locked';
    END IF;
  END IF;

  -- Prevent duplicate signup for authenticated users.
  IF v_user_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM event_session_roster
               WHERE session_id = v_session.id AND user_id = v_user_id) THEN
      RAISE EXCEPTION 'already_signed_up';
    END IF;
  END IF;

  -- ── Payment mode enforcement ────────────────────────────────────────────
  CASE v_session.payment_mode
    WHEN 'pay_first' THEN
      -- Only the webhook (which supplies p_payment_intent_id) may insert the roster row.
      IF p_payment_intent_id IS NULL THEN
        RAISE EXCEPTION 'payment_required';
      END IF;
      v_pay_status := 'paid';
    WHEN 'join_first' THEN
      v_pay_status := 'unpaid';
    WHEN 'track_only' THEN
      v_pay_status := 'unpaid';
    ELSE  -- 'free'
      v_pay_status := 'not_required';
  END CASE;

  -- ── requires_approval path ──────────────────────────────────────────────
  IF v_session.requires_approval THEN
    v_status := 'pending_review';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'pending_review';

    INSERT INTO event_session_roster
      (id, session_id, user_id, display_name, email, phone,
       status, signup_order, payment_status, stripe_payment_intent_id)
    VALUES
      (v_roster_id, v_session.id, v_user_id, p_display_name, p_email, p_phone,
       v_status, v_next_order, v_pay_status, p_payment_intent_id);

    IF v_user_id IS NOT NULL THEN
      INSERT INTO event_guests (event_id, user_id, display_name, email, phone, status, role, rsvp_at)
      VALUES (v_session.event_id, v_user_id, p_display_name, p_email, p_phone, 'accepted', 'member', now())
      ON CONFLICT (event_id, user_id) DO UPDATE
        SET status = 'accepted'
        WHERE event_guests.status IN ('declined', 'left', 'pending');
    END IF;

    SELECT
      COUNT(*) FILTER (WHERE status = 'going'),
      COUNT(*) FILTER (WHERE status = 'waitlisted')
    INTO v_confirmed, v_waitlisted
    FROM event_session_roster WHERE session_id = v_session.id;

    RETURN QUERY SELECT
      v_roster_id, v_next_order, v_status,
      v_confirmed, v_waitlisted, v_session.capacity;
    RETURN;
  END IF;

  -- ── Normal flow ─────────────────────────────────────────────────────────
  SELECT
    COUNT(*) FILTER (WHERE status = 'going'),
    COUNT(*) FILTER (WHERE status = 'waitlisted')
  INTO v_confirmed, v_waitlisted
  FROM event_session_roster WHERE session_id = v_session.id;

  IF v_session.capacity IS NULL OR v_confirmed < v_session.capacity THEN
    v_status := 'going';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'going';
  ELSIF v_session.waitlist_enabled THEN
    v_status := 'waitlisted';
    SELECT COALESCE(MAX(signup_order), 0) + 1 INTO v_next_order
    FROM event_session_roster
    WHERE session_id = v_session.id AND status = 'waitlisted';
  ELSE
    RAISE EXCEPTION 'session_full';
  END IF;

  INSERT INTO event_session_roster
    (id, session_id, user_id, display_name, email, phone,
     status, signup_order, payment_status, stripe_payment_intent_id)
  VALUES
    (v_roster_id, v_session.id, v_user_id, p_display_name, p_email, p_phone,
     v_status, v_next_order, v_pay_status, p_payment_intent_id);

  IF v_user_id IS NOT NULL THEN
    INSERT INTO event_guests (event_id, user_id, display_name, email, phone, status, role, rsvp_at)
    VALUES (v_session.event_id, v_user_id, p_display_name, p_email, p_phone, 'accepted', 'member', now())
    ON CONFLICT (event_id, user_id) DO UPDATE
      SET status = 'accepted'
      WHERE event_guests.status IN ('declined', 'left', 'pending');
  END IF;

  RETURN QUERY SELECT
    v_roster_id,
    CASE WHEN v_status = 'going'
         THEN (v_confirmed + 1)::integer
         ELSE (v_waitlisted + 1)::integer
    END,
    v_status,
    v_confirmed + CASE WHEN v_status = 'going'       THEN 1 ELSE 0 END,
    v_waitlisted + CASE WHEN v_status = 'waitlisted' THEN 1 ELSE 0 END,
    v_session.capacity;
END;
$$;

-- Keep old 4-argument signature as an alias so existing app versions don't break.
GRANT EXECUTE ON FUNCTION rsvp_session(uuid, text, text, text, text) TO anon, authenticated;

-- ── 7. mark_roster_paid — organizer manually marks a roster entry as paid ────

CREATE OR REPLACE FUNCTION mark_roster_paid(p_roster_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_entry   event_session_roster%ROWTYPE;
  v_session event_sessions%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM event_session_roster WHERE id = p_roster_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;

  SELECT * INTO v_session FROM event_sessions WHERE id = v_entry.session_id;

  IF NOT EXISTS (
    SELECT 1 FROM events WHERE id = v_session.event_id AND created_by = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_organizer';
  END IF;

  UPDATE event_session_roster
  SET payment_status = 'paid', paid_at = now()
  WHERE id = p_roster_id;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_roster_paid(uuid) TO authenticated;

-- ── 8. update_connect_account — called by stripe-connect-onboard edge fn ─────
-- Service role only; not exposed to authenticated users.

CREATE OR REPLACE FUNCTION update_connect_account(
  p_user_id                     uuid,
  p_stripe_connect_account_id   text,
  p_charges_enabled             boolean DEFAULT false
)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  INSERT INTO user_profiles (user_id, stripe_connect_account_id, stripe_connect_charges_enabled)
  VALUES (p_user_id, p_stripe_connect_account_id, p_charges_enabled)
  ON CONFLICT (user_id) DO UPDATE
    SET stripe_connect_account_id     = p_stripe_connect_account_id,
        stripe_connect_charges_enabled = p_charges_enabled;
$$;

-- Grant to service_role only — edge functions use service role key.
REVOKE EXECUTE ON FUNCTION update_connect_account(uuid, text, boolean) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION update_connect_account(uuid, text, boolean) TO service_role;
