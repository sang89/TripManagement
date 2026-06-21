-- Restore `requires_approval` to get_session_by_invite_code.
--
-- Regression: migration 20260612000001_revert_paid_registration.sql redefined
-- get_session_by_invite_code while reverting the paid-registration changes and
-- accidentally dropped the `requires_approval` column from its RETURNS TABLE.
-- The column still exists on event_sessions and rsvp_session honours it, but
-- the public getter no longer exposed it — so the QR-scan join sheet and the
-- public session-invite page always treated sessions as not requiring approval
-- and showed "Claim spot" instead of "Request to join".

DROP FUNCTION IF EXISTS get_session_by_invite_code(uuid);

CREATE OR REPLACE FUNCTION get_session_by_invite_code(p_invite_code uuid)
RETURNS TABLE(
  session_id        uuid,
  event_id          uuid,
  session_number    integer,
  title             text,
  description       text,
  location          text,
  location_lat      double precision,
  location_lng      double precision,
  start_at          timestamptz,
  end_at            timestamptz,
  capacity          integer,
  going_count       bigint,
  waitlist_count    bigint,
  organizer_name    text,
  waitlist_enabled  boolean,
  signup_lock_hours integer,
  requires_approval boolean
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
    s.requires_approval
  FROM event_sessions s
  JOIN events e ON e.id = s.event_id
  LEFT JOIN event_session_roster r ON r.session_id = s.id
  WHERE s.invite_code = p_invite_code
  GROUP BY s.id, s.session_number, s.start_at, s.end_at,
           e.id, e.title, e.description, e.location,
           e.location_lat, e.location_lng, e.capacity,
           s.capacity, s.waitlist_enabled, s.signup_lock_hours,
           s.requires_approval, e.created_by;
$$;

GRANT EXECUTE ON FUNCTION get_session_by_invite_code(uuid) TO anon, authenticated;
